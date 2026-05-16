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

  class NoStdinStreamingCliAgent < StreamingCliAgent
    private

    def stdin_for(_instruction)
      nil
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

  it "records elapsed wall-clock seconds around command execution" do
    times = [10.0, 12.75]
    executor = ->(_command, _instruction, working_directory:) { ["done", "", CliAgentStatus.new(true)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = TestCliAgent.new(
      command: "tool",
      executor: executor,
      monotonic_clock: -> { times.shift }
    ).call(task)

    expect(result.elapsed_seconds).to eq(2.75)
  end

  it "captures token and cost usage when the CLI emits common verbose labels" do
    executor = lambda do |_command, _instruction, working_directory:|
      [
        "input tokens: 1,234\noutput tokens: 56\ncached tokens: 789\ntotal tokens: 2,079\nestimated cost: $0.0123",
        "",
        CliAgentStatus.new(true)
      ]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = TestCliAgent.new(command: "tool", executor: executor).call(task)

    expect(result.usage).to eq(
      input_tokens: 1234,
      output_tokens: 56,
      cached_tokens: 789,
      total_tokens: 2079,
      estimated_cost: 0.0123
    )
  end

  it "supports provider-specific usage parsers" do
    executor = ->(_command, _instruction, working_directory:) { ["provider-specific output", "", CliAgentStatus.new(true)] }
    parser = ->(stdout, stderr) { { raw_usage: "#{stdout}/#{stderr}".strip } }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = TestCliAgent.new(command: "tool", executor: executor, usage_parser: parser).call(task)

    expect(result.usage).to eq(raw_usage: "provider-specific output/")
  end

  it "emits instruction, output, and command finished events" do
    events = []
    executor = lambda do |_command, _instruction, working_directory:|
      [
        "input tokens: 10\noutput tokens: 5\n",
        "diagnostic",
        CliAgentStatus.new(true)
      ]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    TestCliAgent.new(command: "tool", executor: executor, observer: ->(event) { events << event }).call(task)

    expect(events.map(&:type)).to include(
      "agent.instruction",
      "agent.command.started",
      "agent.stdout",
      "agent.stderr",
      "agent.command.finished"
    )
    finished = events.find { |event| event.type == "agent.command.finished" }
    expect(finished.data[:usage]).to include(input_tokens: 10, output_tokens: 5)
  end

  it "raises execution errors on failed status" do
    times = [10.0, 11.5]
    executor = ->(_command, _instruction, working_directory:) { ["", "nope", CliAgentStatus.new(false)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor, monotonic_clock: -> { times.shift }).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.message).to include("tool failed for one: nope")
      expect(error.result.elapsed_seconds).to eq(1.5)
    }
  end

  it "raises execution errors when the command cannot be spawned" do
    times = [10.0, 10.25]
    executor = lambda do |_command, _instruction, working_directory:|
      raise Errno::ENOENT, "tool"
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor, monotonic_clock: -> { times.shift }).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.message).to include("command not found: tool")
      expect(error.result.status).not_to be_success
      expect(error.result.elapsed_seconds).to eq(0.25)
    }
  end

  it "emits command spawn failure events" do
    events = []
    executor = lambda do |_command, _instruction, working_directory:|
      raise Errno::ENOENT, "tool"
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor, observer: ->(event) { events << event }).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError)

    spawn_failed = events.find { |event| event.type == "agent.command.spawn_failed" }
    expect(spawn_failed.data).to include(error_class: "Errno::ENOENT")
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
    expect(stderr.string).to end_with("visible error")
    expect(result.stdout).to eq(stdout.string)
    expect(result.stderr).to eq(stderr.string)
  end

  it "emits subprocess chunks while streaming" do
    events = []
    agent = StreamingCliAgent.new(
      command: RbConfig.ruby,
      extra_args: [
        "-e",
        "STDOUT.write('visible output'); STDERR.write('visible error')"
      ],
      stream: true,
      stdout: nil,
      stderr: nil,
      observer: ->(event) { events << event }
    )
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    agent.call(task)

    expect(events.select { |event| event.type == "agent.stdout" }.map { |event| event.data[:chunk] }.join).to include("visible output")
    expect(events.select { |event| event.type == "agent.stderr" }.map { |event| event.data[:chunk] }.join).to include("visible error")
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
    expect(result.stderr).to end_with("hidden error")
  end

  it "can stream subprocess output without writing stdin" do
    stdout = StringIO.new
    agent = NoStdinStreamingCliAgent.new(
      command: RbConfig.ruby,
      extra_args: [
        "-e",
        "input = STDIN.read; STDOUT.write(input.empty? ? 'no stdin' : input)"
      ],
      stream: true,
      stdout: stdout
    )
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = agent.call(task)

    expect(stdout.string).to eq("no stdin")
    expect(result.instruction).to include("Task ID: one")
  end
end
