# frozen_string_literal: true

RSpec.describe EminenceGrise::ResultHandler do
  it "ignores non-agent results" do
    queue = EminenceGrise::MemoryQueue.new

    described_class.new(queue: queue, logger: EminenceGrise::Logging.null).call("done")

    expect(queue).to be_empty
  end

  it "raises failed results" do
    queue = EminenceGrise::MemoryQueue.new

    expect do
      described_class.new(queue: queue, logger: EminenceGrise::Logging.null)
                     .call(EminenceGrise::AgentResult.failed("nope"))
    end.to raise_error(RuntimeError, "nope")
  end

  it "enqueues generated tasks in order" do
    queue = EminenceGrise::MemoryQueue.new
    first = EminenceGrise::Task.new(id: "one", title: "First")
    second = EminenceGrise::Task.new(id: "two", title: "Second")

    described_class.new(queue: queue, logger: EminenceGrise::Logging.null)
                   .call(EminenceGrise::AgentResult.complete(tasks: [first, second]))

    expect(queue.pop).to eq(first)
    expect(queue.pop).to eq(second)
  end
end
