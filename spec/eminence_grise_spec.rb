# frozen_string_literal: true

RSpec.describe EminenceGrise::Runner do
  RetryAtError = Class.new(StandardError) do
    attr_reader :retry_at

    def initialize(retry_at)
      @retry_at = retry_at
      super("retry later")
    end
  end

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

  it "enqueues tasks returned by agent results" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    processed = []
    agent = EminenceGrise::Agent.new do |task|
      processed << task.id
      EminenceGrise::AgentResult.complete(tasks: [
        EminenceGrise::Task.new(id: "two", title: "Second")
      ]) if task.id == "one"
    end

    count = described_class.new(queue: queue, agent: agent).run

    expect(count).to eq(2)
    expect(processed).to eq(["one", "two"])
  end

  it "raises failed agent results" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    agent = EminenceGrise::Agent.new { |_task| EminenceGrise::AgentResult.failed("nope") }

    expect do
      described_class.new(queue: queue, agent: agent).run
    end.to raise_error(RuntimeError, "nope")
  end

  it "waits until retry_at and retries the same task" do
    retry_at = Time.iso8601("2026-05-02T15:00:05-04:00")
    now = Time.iso8601("2026-05-02T15:00:00-04:00")
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    attempts = 0
    sleeps = []
    agent = EminenceGrise::Agent.new do |_task|
      attempts += 1
      raise RetryAtError, retry_at if attempts == 1
    end

    count = described_class.new(
      queue: queue,
      agent: agent,
      sleeper: ->(seconds) { sleeps << seconds },
      clock: -> { now }
    ).run

    expect(count).to eq(1)
    expect(attempts).to eq(2)
    expect(sleeps).to eq([5])
    expect(queue).to be_empty
  end

  it "raises retry_at errors when waiting is disabled" do
    retry_at = Time.iso8601("2026-05-02T15:00:05-04:00")
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    agent = EminenceGrise::Agent.new { |_task| raise RetryAtError, retry_at }

    expect do
      described_class.new(queue: queue, agent: agent, wait_on_retry_at: false).run
    end.to raise_error(RetryAtError)
  end
end
