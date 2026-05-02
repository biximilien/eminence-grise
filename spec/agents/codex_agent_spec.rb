# frozen_string_literal: true

RSpec.describe EminenceGrise::CodexAgent do
  CodexStatus = Struct.new(:success?)

  it "runs codex exec with the task instruction on stdin" do
    calls = []
    executor = lambda do |command, instruction, working_directory:|
      calls << [command, instruction, working_directory]
      ["done", "", CodexStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README", description: "Write useful docs.")

    result = described_class.new(working_directory: "/repo", executor: executor).call(task)

    expect(result.stdout).to eq("done")
    expect(calls).to eq([
      [
        ["codex", "exec", "-C", "/repo", "--sandbox", "workspace-write", "--ask-for-approval", "never", "-"],
        "Task ID: one\n\nTitle: Add README\n\nDescription:\nWrite useful docs.",
        "/repo"
      ]
    ])
  end

  it "supports model and extra Codex CLI arguments" do
    command = nil
    executor = lambda do |args, _instruction, working_directory:|
      command = args
      ["", "", CodexStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(model: "gpt-5.4", extra_args: ["--ephemeral"], executor: executor).call(task)

    expect(command).to include("--model", "gpt-5.4", "--ephemeral")
    expect(command.last).to eq("-")
  end

  it "raises when codex exec fails" do
    executor = lambda do |_command, _instruction, working_directory:|
      ["", "nope", CodexStatus.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      described_class.new(executor: executor).call(task)
    end.to raise_error(EminenceGrise::CodexAgent::ExecutionError, /nope/)
  end

  it "keeps result and error constants available" do
    expect(described_class::Result).to eq(EminenceGrise::CliAgent::Result)
    expect(described_class::ExecutionError).to be < EminenceGrise::CliAgent::ExecutionError
  end

  it "extracts a retry time from Codex limit errors" do
    retry_at = Time.iso8601("2026-05-02T15:30:00-04:00")
    executor = lambda do |_command, _instruction, working_directory:|
      ["", "usage limit reached; try again at 2026-05-02T15:30:00-04:00", CodexStatus.new(false)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    expect do
      described_class.new(executor: executor).call(task)
    end.to raise_error(EminenceGrise::CodexAgent::ExecutionError) { |error|
      expect(error.retry_at).to eq(retry_at)
    }
  end
end
