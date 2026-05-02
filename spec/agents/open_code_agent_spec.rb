# frozen_string_literal: true

RSpec.describe EminenceGrise::OpenCodeAgent do
  OpenCodeStatus = Struct.new(:success?)

  it "runs opencode in non-interactive run mode" do
    command = nil
    instruction = nil
    stdin_data = :unset
    executor = lambda do |args, stdin, working_directory:|
      command = args
      stdin_data = stdin
      ["done", "", OpenCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    result = described_class.new(executor: executor).call(task)

    instruction = result.instruction
    expect(command).to eq(["opencode", "run", instruction])
    expect(command.last).to eq(instruction)
    expect(stdin_data).to be_nil
  end

  it "supports model, agent, output format, and extra arguments" do
    command = nil
    executor = lambda do |args, _instruction, working_directory:|
      command = args
      ["done", "", OpenCodeStatus.new(true)]
    end
    task = EminenceGrise::Task.new(id: "one", title: "Add README")

    described_class.new(
      model: "anthropic/claude-sonnet-4-5",
      agent: "reviewer",
      output_format: "json",
      extra_args: ["--continue"],
      executor: executor
    ).call(task)

    expect(command).to include("--model", "anthropic/claude-sonnet-4-5")
    expect(command).to include("--agent", "reviewer")
    expect(command).to include("--format", "json")
    expect(command).to include("--continue")
  end
end
