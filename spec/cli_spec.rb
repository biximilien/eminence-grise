# frozen_string_literal: true

require "stringio"
require "eminence_grise/cli"

RSpec.describe EminenceGrise::CLI do
  class FakeProcessRunner
    attr_reader :options, :close_count

    class << self
      attr_accessor :daemon_running, :foreground_error, :stop_result
    end

    def initialize(**options)
      @options = options
      @close_count = 0
    end

    def run_foreground
      raise self.class.foreground_error if self.class.foreground_error
    end

    def start_daemon
      321
    end

    def stop_daemon
      self.class.stop_result
    end

    def daemon_running?
      self.class.daemon_running
    end

    def daemon_pid
      321
    end

    def close
      @close_count += 1
    end
  end

  before do
    FakeProcessRunner.daemon_running = true
    FakeProcessRunner.foreground_error = nil
    FakeProcessRunner.stop_result = true
  end

  it "passes logging options to ProcessRunner" do
    runners = []
    allow(EminenceGrise::ProcessRunner).to receive(:new) do |**options|
      FakeProcessRunner.new(**options).tap { |runner| runners << runner }
    end
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = described_class.new(
      [
        "run",
        "examples/basic_loop.rb",
        "--background",
        "--log",
        "tmp/framework.log",
        "--log-format",
        "json",
        "--log-level",
        "debug"
      ],
      stdout: stdout,
      stderr: stderr
    ).call

    expect(exit_code).to eq(0)
    expect(stdout.string).to include("started pid 321")
    expect(stderr.string).to be_empty
    expect(runners.first.options).to include(
      script: "examples/basic_loop.rb",
      log_path: "tmp/framework.log",
      log_format: :json,
      log_level: "debug"
    )
  end

  it "closes a foreground runner" do
    runners = capture_runners
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = described_class.new(["run", "examples/basic_loop.rb"], stdout: stdout, stderr: stderr).call

    expect(exit_code).to eq(0)
    expect(runners.first.close_count).to eq(1)
  end

  it "closes a background runner" do
    runners = capture_runners
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = described_class.new(["run", "examples/basic_loop.rb", "--background"], stdout: stdout, stderr: stderr).call

    expect(exit_code).to eq(0)
    expect(stdout.string).to include("started pid 321")
    expect(runners.first.close_count).to eq(1)
  end

  it "closes a foreground runner when the run raises" do
    error = RuntimeError.new("boom")
    FakeProcessRunner.foreground_error = error
    runners = capture_runners

    expect do
      described_class.new(["run", "examples/basic_loop.rb"], stdout: StringIO.new, stderr: StringIO.new).call
    end.to raise_error(error)

    expect(runners.first.close_count).to eq(1)
  end

  it "closes a status runner" do
    runners = capture_runners
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = described_class.new(["status"], stdout: stdout, stderr: stderr).call

    expect(exit_code).to eq(0)
    expect(stdout.string).to include("running pid 321")
    expect(runners.first.close_count).to eq(1)
  end

  it "closes a stop runner" do
    runners = capture_runners
    stdout = StringIO.new
    stderr = StringIO.new

    exit_code = described_class.new(["stop"], stdout: stdout, stderr: stderr).call

    expect(exit_code).to eq(0)
    expect(stdout.string).to include("stopped")
    expect(runners.first.close_count).to eq(1)
  end

  def capture_runners
    runners = []
    allow(EminenceGrise::ProcessRunner).to receive(:new) do |**options|
      FakeProcessRunner.new(**options).tap { |runner| runners << runner }
    end
    runners
  end
end
