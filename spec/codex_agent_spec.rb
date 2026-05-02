# frozen_string_literal: true

RSpec.describe EminenceGrise::CodexAgent do
  Status = Struct.new(:success?)

  it "runs codex exec with the task instruction on stdin" do
    calls = []
    executor = lambda do |command, instruction|
      calls << [command, instruction]
      ["done", "", Status.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README", description: "Write useful docs.")

    result = described_class.new(working_directory: "/repo", executor: executor).call(task)

    expect(result.stdout).to eq("done")
    expect(calls).to eq([
      [
        ["codex", "exec", "-C", "/repo", "--sandbox", "workspace-write", "--ask-for-approval", "never", "-"],
        "Task ID: one\n\nTitle: Add README\n\nDescription:\nWrite useful docs."
      ]
    ])
  end

  it "supports model and extra Codex CLI arguments" do
    command = nil
    executor = lambda do |args, _instruction|
      command = args
      ["", "", Status.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(model: "gpt-5.4", extra_args: ["--ephemeral"], executor: executor).call(task)

    expect(command).to include("--model", "gpt-5.4", "--ephemeral")
    expect(command.last).to eq("-")
  end

  it "raises when codex exec fails" do
    executor = lambda do |_command, _instruction|
      ["", "nope", Status.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      described_class.new(executor: executor).call(task)
    end.to raise_error(EminenceGrise::CodexAgent::ExecutionError, /nope/)
  end
end
