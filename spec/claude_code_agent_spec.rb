# frozen_string_literal: true

RSpec.describe EminenceGrise::ClaudeCodeAgent do
  ClaudeCodeStatus = Struct.new(:success?)

  it "runs claude in print mode with text output" do
    command = nil
    instruction = nil
    executor = lambda do |args, text, working_directory:|
      command = args
      instruction = text
      ["done", "", ClaudeCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(executor: executor).call(task)

    expect(command).to eq(["claude", "-p", "--output-format", "text", instruction])
    expect(command.last).to eq(instruction)
  end

  it "supports model, permission mode, and extra arguments" do
    command = nil
    executor = lambda do |args, _instruction, working_directory:|
      command = args
      ["done", "", ClaudeCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(
      model: "sonnet",
      permission_mode: "plan",
      extra_args: ["--max-turns", "3"],
      executor: executor
    ).call(task)

    expect(command).to include("--model", "sonnet")
    expect(command).to include("--permission-mode", "plan")
    expect(command).to include("--max-turns", "3")
  end
end
