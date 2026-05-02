# frozen_string_literal: true

RSpec.describe EminenceGrise::ClaudeCodeAgent do
  ClaudeCodeStatus = Struct.new(:success?)

  it "runs claude in print mode with text output" do
    command = nil
    instruction = nil
    stdin_data = :unset
    directory = nil
    executor = lambda do |args, stdin, working_directory:|
      command = args
      stdin_data = stdin
      directory = working_directory
      ["done", "", ClaudeCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = described_class.new(working_directory: "/workspace", executor: executor).call(task)

    instruction = result.instruction
    expect(command).to eq(["claude", "-p", "--output-format", "text", instruction])
    expect(command.last).to eq(instruction)
    expect(stdin_data).to be_nil
    expect(directory).to eq("/workspace")
  end

  it "supports json output format" do
    command = nil
    executor = lambda do |args, _instruction, working_directory:|
      command = args
      ["done", "", ClaudeCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(output_format: "json", executor: executor).call(task)

    expect(command).to include("--output-format", "json")
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
