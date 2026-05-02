# frozen_string_literal: true

RSpec.describe EminenceGrise::ProcessRunner do
  class FakeDaemon
    attr_reader :options

    def initialize(**options)
      @options = options
    end

    def start
      123
    end

    def stop
      true
    end

    def running?
      true
    end

    def pid
      123
    end
  end

  it "loads a loop script in the foreground" do
    loaded = []
    runner = described_class.new(
      script: "examples/basic_loop.rb",
      require_path: "./lib",
      working_directory: Dir.pwd,
      logger: EminenceGrise::Logging.null,
      loader: ->(script) { loaded << [script, Dir.pwd, $LOAD_PATH.first] }
    )

    runner.run_foreground

    expect(loaded).to eq([["examples/basic_loop.rb", Dir.pwd, "./lib"]])
  end

  it "restores the load path after foreground execution" do
    original_load_path = $LOAD_PATH.dup
    runner = described_class.new(
      script: "examples/basic_loop.rb",
      require_path: "temporary/lib",
      logger: EminenceGrise::Logging.null,
      loader: ->(_script) { expect($LOAD_PATH.first).to eq("temporary/lib") }
    )

    runner.run_foreground

    expect($LOAD_PATH).to eq(original_load_path)
  end

  it "starts a daemon using the configured Ruby command" do
    runner = described_class.new(
      script: "examples/codex_loop.rb",
      ruby: "ruby",
      require_path: "./lib",
      pidfile: "tmp/runner.pid",
      stdout: "tmp/runner.out.log",
      stderr: "tmp/runner.err.log",
      logger: EminenceGrise::Logging.null,
      daemon_class: FakeDaemon
    )

    expect(runner.start_daemon).to eq(123)
    expect(runner.daemon.options).to include(
      command: ["ruby", "-I", "./lib", "examples/codex_loop.rb"],
      pidfile: "tmp/runner.pid",
      stdout: "tmp/runner.out.log",
      stderr: "tmp/runner.err.log"
    )
  end

  it "auto-detects the require path from the working directory" do
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "lib"))
      runner = described_class.new(
        script: "worker.rb",
        ruby: "ruby",
        working_directory: dir,
        logger: EminenceGrise::Logging.null,
        daemon_class: FakeDaemon
      )

      runner.start_daemon

      expect(runner.daemon.options[:command]).to eq(["ruby", "-I", "./lib", "worker.rb"])
    end
  end

  it "omits the require path when it is disabled" do
    runner = described_class.new(
      script: "worker.rb",
      ruby: "ruby",
      require_path: nil,
      logger: EminenceGrise::Logging.null,
      daemon_class: FakeDaemon
    )

    runner.start_daemon

    expect(runner.daemon.options[:command]).to eq(["ruby", "worker.rb"])
  end

  it "preserves an explicit require path" do
    runner = described_class.new(
      script: "worker.rb",
      ruby: "ruby",
      require_path: "custom/lib",
      logger: EminenceGrise::Logging.null,
      daemon_class: FakeDaemon
    )

    runner.start_daemon

    expect(runner.daemon.options[:command]).to eq(["ruby", "-I", "custom/lib", "worker.rb"])
  end

  it "exposes daemon status operations" do
    runner = described_class.new(script: nil, logger: EminenceGrise::Logging.null, daemon_class: FakeDaemon)

    expect(runner.daemon_running?).to be(true)
    expect(runner.daemon_pid).to eq(123)
    expect(runner.stop_daemon).to be(true)
  end

  it "requires a script for foreground and daemon starts" do
    runner = described_class.new(script: nil, logger: EminenceGrise::Logging.null, daemon_class: FakeDaemon)

    expect { runner.run_foreground }.to raise_error(ArgumentError, /script is required/)
    expect { runner.start_daemon }.to raise_error(ArgumentError, /script is required/)
  end

  it "defaults daemon logging to the framework log file" do
    Dir.mktmpdir do |dir|
      log_path = File.join(dir, "runner.log")
      runner = described_class.new(
        script: "worker.rb",
        ruby: "ruby",
        require_path: nil,
        log_path: log_path,
        daemon_class: FakeDaemon
      )

      runner.start_daemon

      expect(File.read(log_path)).to include("daemon started")
      runner.close
    end
  end

  it "does not close user-provided loggers" do
    logger = instance_double(Logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    allow(logger).to receive(:close)
    runner = described_class.new(
      script: "worker.rb",
      logger: logger,
      daemon_class: FakeDaemon
    )

    runner.start_daemon
    runner.close

    expect(logger).not_to have_received(:close)
  end
end
