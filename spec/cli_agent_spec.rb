# frozen_string_literal: true

RSpec.describe EminenceGrise::CliAgent do
  CliAgentStatus = Struct.new(:success?)

  class TestCliAgent < EminenceGrise::CliAgent
    private

    def command_for(instruction)
      [command, "run", instruction]
    end
  end

  it "builds the standard task instruction" do
    calls = []
    executor = lambda do |command, instruction|
      calls << [command, instruction]
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

    expect(calls.first.last).to include("Task ID: one")
    expect(calls.first.last).to include("Title: Add README")
    expect(calls.first.last).to include("Description:\nWrite useful docs.")
    expect(calls.first.last).to include("\"agent\": \"docs\"")
  end

  it "returns result on successful status" do
    executor = ->(_command, _instruction) { ["done", "", CliAgentStatus.new(true)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = TestCliAgent.new(command: "tool", executor: executor).call(task)

    expect(result.stdout).to eq("done")
    expect(result.task).to eq(task)
  end

  it "raises execution errors on failed status" do
    executor = ->(_command, _instruction) { ["", "nope", CliAgentStatus.new(false)] }
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError, /tool failed for one: nope/)
  end

  it "extracts retry timestamps from failed output" do
    retry_at = Time.iso8601("2026-05-02T15:30:00-04:00")
    executor = lambda do |_command, _instruction|
      ["", "rate limit reset at 2026-05-02T15:30:00-04:00", CliAgentStatus.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      TestCliAgent.new(command: "tool", executor: executor).call(task)
    end.to raise_error(EminenceGrise::CliAgent::ExecutionError) { |error|
      expect(error.retry_at).to eq(retry_at)
    }
  end
end
