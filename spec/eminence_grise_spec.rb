# frozen_string_literal: true

RSpec.describe EminenceGrise::Runner do
  it "processes tasks sequentially" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First"),
      EminenceGrise::Task.new(id: "two", title: "Second")
    ])
    processed = []
    agent = EminenceGrise::Agent.new { |task| processed << task.id }

    count = described_class.new(queue: queue, agent: agent).run

    expect(count).to eq(2)
    expect(processed).to eq(["one", "two"])
    expect(queue).to be_empty
  end

  it "can stop after a maximum number of tasks" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First"),
      EminenceGrise::Task.new(id: "two", title: "Second")
    ])
    agent = EminenceGrise::Agent.new { |_task| }

    count = described_class.new(queue: queue, agent: agent).run(max_tasks: 1)

    expect(count).to eq(1)
    expect(queue.size).to eq(1)
  end
end
