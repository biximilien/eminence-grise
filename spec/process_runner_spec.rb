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
      loader: ->(script) { loaded << [script, Dir.pwd, $LOAD_PATH.first] }
    )

    runner.run_foreground

    expect(loaded).to eq([["examples/basic_loop.rb", Dir.pwd, "./lib"]])
  end

  it "starts a daemon using the configured Ruby command" do
    runner = described_class.new(
      script: "examples/codex_loop.rb",
      ruby: "ruby",
      require_path: "./lib",
      pidfile: "tmp/runner.pid",
      stdout: "tmp/runner.out.log",
      stderr: "tmp/runner.err.log",
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

  it "exposes daemon status operations" do
    runner = described_class.new(script: nil, daemon_class: FakeDaemon)

    expect(runner.daemon_running?).to be(true)
    expect(runner.daemon_pid).to eq(123)
    expect(runner.stop_daemon).to be(true)
  end

  it "requires a script for foreground and daemon starts" do
    runner = described_class.new(script: nil, daemon_class: FakeDaemon)

    expect { runner.run_foreground }.to raise_error(ArgumentError, /script is required/)
    expect { runner.start_daemon }.to raise_error(ArgumentError, /script is required/)
  end
end
