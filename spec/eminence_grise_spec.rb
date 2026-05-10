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

  it "runs workflow hooks around successful agent execution before result handling" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    events = []
    after_queue_size = nil
    workflow = Object.new
    workflow.define_singleton_method(:before_task) { |_task| events << :before }
    workflow.define_singleton_method(:after_task) do |_task, _result|
      events << :after
      after_queue_size = queue.size
    end
    agent = EminenceGrise::Agent.new do |_task|
      events << :agent
      EminenceGrise::AgentResult.complete(tasks: [
        EminenceGrise::Task.new(id: "two", title: "Second")
      ])
    end

    count = described_class.new(queue: queue, agent: agent, workflow: workflow).run(max_tasks: 1)

    expect(count).to eq(1)
    expect(events).to eq([:before, :agent, :after])
    expect(after_queue_size).to eq(0)
    expect(queue.size).to eq(1)
  end

  it "does not run workflow after_task when the agent raises" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    after_called = false
    workflow = Object.new
    workflow.define_singleton_method(:before_task) { |_task| }
    workflow.define_singleton_method(:after_task) { |_task, _result| after_called = true }
    agent = EminenceGrise::Agent.new { |_task| raise "boom" }

    expect do
      described_class.new(queue: queue, agent: agent, workflow: workflow).run
    end.to raise_error(RuntimeError, "boom")
    expect(after_called).to be(false)
  end

  it "does not run workflow after_task for failed agent results" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    after_called = false
    workflow = Object.new
    workflow.define_singleton_method(:before_task) { |_task| }
    workflow.define_singleton_method(:after_task) { |_task, _result| after_called = true }
    agent = EminenceGrise::Agent.new { |_task| EminenceGrise::AgentResult.failed("nope") }

    expect do
      described_class.new(queue: queue, agent: agent, workflow: workflow).run
    end.to raise_error(RuntimeError, "nope")
    expect(after_called).to be(false)
  end

  it "logs task lifecycle and enqueued tasks through logger levels" do
    logger = instance_double(Logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    agent = EminenceGrise::Agent.new do |task|
      EminenceGrise::AgentResult.complete(tasks: [
        EminenceGrise::Task.new(id: "two", title: "Second")
      ]) if task.id == "one"
    end

    described_class.new(queue: queue, agent: agent, logger: logger).run

    expect(logger).to have_received(:info).with(/task started id=one/)
    expect(logger).to have_received(:info).with(/task enqueued id=two/)
    expect(logger).to have_received(:info).with(/task finished id=one/)
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

  it "logs task failures before raising" do
    logger = instance_double(Logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    agent = EminenceGrise::Agent.new { |_task| raise "boom" }

    expect do
      described_class.new(queue: queue, agent: agent, logger: logger).run
    end.to raise_error(RuntimeError, "boom")
    expect(logger).to have_received(:error).with(/task failed id=one/)
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

  it "logs retry waits with warn" do
    retry_at = Time.iso8601("2026-05-02T15:00:05-04:00")
    now = Time.iso8601("2026-05-02T15:00:00-04:00")
    logger = instance_double(Logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    attempts = 0
    agent = EminenceGrise::Agent.new do |_task|
      attempts += 1
      raise RetryAtError, retry_at if attempts == 1
    end

    described_class.new(
      queue: queue,
      agent: agent,
      logger: logger,
      sleeper: ->(_seconds) {},
      clock: -> { now }
    ).run

    expect(logger).to have_received(:warn).with(/task retry waiting id=one/)
  end

  it "supports puts-only loggers" do
    messages = []
    logger = Object.new
    logger.define_singleton_method(:puts) { |message| messages << message }
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "one", title: "First")
    ])
    agent = EminenceGrise::Agent.new { |_task| }

    described_class.new(queue: queue, agent: agent, logger: logger).run

    expect(messages).to include(/task started id=one/)
    expect(messages).to include(/task finished id=one/)
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
