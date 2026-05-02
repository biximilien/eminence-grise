# frozen_string_literal: true

require "rbconfig"
require "stringio"

RSpec.describe EminenceGrise::CliAgent do
  CliAgentStatus = Struct.new(:success?)

  class TestCliAgent < EminenceGrise::CliAgent
    private

    def command_for(instruction)
      [command, "run", instruction]
    end
  end

  class StreamingCliAgent < EminenceGrise::CliAgent
    private

    def command_for(_instruction)
      [command, *extra_args]
    end
  end

  it "builds the standard task instruction" do
    calls = []
    executor = lambda do |command, instruction, working_directory:|
      calls << [command, instruction, working_directory]
      ["ok", "", CliAgentStatus.new(true)]
    end
    task = EminenceGrise::Task.new(
      id: "one",
      title: "Add README",
      description: "Write useful docs.",
      metadata: { agent: :docs }
    )

    described_class = TestCliAgent
    described_class.new(command: "tool", executor: executor).call(task)

    expect(calls.first[1]).to include("Task ID: one")
    expect(calls.first[1]).to include("Title: Add README")
    expect(calls.first[1]).to include("Description:\nWrite useful docs.")
    expect(calls.first[1]).to include("\"agent\": \"docs\"")
  end

  it "returns result on successful status" do
    executor = ->(_command, _instruction, working_directory:) { ["done", working_directory, CliAgentStatus.new(true)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = TestCliAgent.new(command: "tool", working_directory: "/repo", executor: executor).call(task)

    expect(result.stdout).to eq("done")
    expect(result.stderr).to eq("/repo")
    expect(result.task).to eq(task)
  end

  it "raises execution errors on failed status" do
    executor = ->(_command, _instruction, working_directory:) { ["", "nope", CliAgentStatus.new(false)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError, /tool failed for one: nope/)
  end

  it "summarizes noisy failed output" do
    executor = lambda do |_command, _instruction, working_directory:|
      [
        "",
        "WARN sync failed with status 403 Forbidden: <html><body>huge challenge</body></html>\nERROR: You've hit your usage limit. Try again at 1:14 PM.",
        CliAgentStatus.new(false)
      ]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.message).to include("You've hit your usage limit")
      expect(error.message).not_to include("<html>")
    }
  end

  it "extracts retry timestamps from failed output" do
    retry_at = Time.iso8601("2026-05-02T15:30:00-04:00")
    executor = lambda do |_command, _instruction, working_directory:|
      ["", "rate limit reset at 2026-05-02T15:30:00-04:00", CliAgentStatus.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.retry_at).to eq(retry_at)
    }
  end

  it "extracts natural retry timestamps with trailing punctuation" do
    executor = lambda do |_command, _instruction, working_directory:|
      ["", "ERROR: usage limit reached; try again at 1:14 PM.", CliAgentStatus.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.retry_at).to be_a(Time)
      expect(error.retry_at.hour).to eq(13)
      expect(error.retry_at.min).to eq(14)
    }
  end

  it "passes working_directory to injected executors" do
    seen_working_directory = nil
    executor = lambda do |_command, _instruction, working_directory:|
      seen_working_directory = working_directory
      ["ok", "", CliAgentStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    TestCliAgent.new(command: "tool", working_directory: "/workspace", executor: executor).call(task)

    expect(seen_working_directory).to eq("/workspace")
  end

  it "can stream subprocess output while preserving the result" do
    stdout = StringIO.new
    stderr = StringIO.new
    agent = StreamingCliAgent.new(
      command: RbConfig.ruby,
      extra_args: [
        "-e",
        "input = STDIN.read; STDOUT.write(input.lines.first); STDERR.write('visible error')"
      ],
      stream: true,
      stdout: stdout,
      stderr: stderr
    )
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = agent.call(task)

    expect(stdout.string).to match(/\ATask ID: one\r?\n\z/)
    expect(stderr.string).to eq("visible error")
    expect(result.stdout).to eq(stdout.string)
    expect(result.stderr).to eq(stderr.string)
  end

  it "can capture stderr without streaming it" do
    stdout = StringIO.new
    agent = StreamingCliAgent.new(
      command: RbConfig.ruby,
      extra_args: [
        "-e",
        "input = STDIN.read; STDOUT.write(input.lines.first); STDERR.write('hidden error')"
      ],
      stream: true,
      stdout: stdout,
      stderr: nil
    )
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = agent.call(task)

    expect(stdout.string).to match(/\ATask ID: one\r?\n\z/)
    expect(result.stderr).to eq("hidden error")
  end
end
