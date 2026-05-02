# frozen_string_literal: true

require "stringio"
require "eminence_grise/cli"

RSpec.describe EminenceGrise::CLI do
  class FakeProcessRunner
    attr_reader :options

    def initialize(**options)
      @options = options
    end

    def start_daemon
      321
    end
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
end
