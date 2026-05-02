# frozen_string_literal: true

RSpec.describe "job integrations" do
  JobRetryAtError = Class.new(StandardError) do
    attr_reader :retry_at

    def initialize(retry_at)
      @retry_at = retry_at
      super("retry later")
    end
  end

  class FakeJobLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def info(message)
      @messages << [:info, message]
    end

    def warn(message)
      @messages << [:warn, message]
    end

    def error(message)
      @messages << [:error, message]
    end
  end

  it "processes one ActiveJob hash payload" do
    processed = []
    agent = EminenceGrise::Agent.new { |task| processed << [task.id, task.title, task.description, task.metadata] }
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
    end

    count = job_class.new.perform(
      "id" => "task-1",
      "title" => "Fix specs",
      "description" => "Run the suite.",
      "metadata" => { "source" => "admin" }
    )

    expect(count).to eq(1)
    expect(processed).to eq([["task-1", "Fix specs", "Run the suite.", { "source" => "admin" }]])
  end

  it "processes one Sidekiq hash payload" do
    processed = []
    agent = EminenceGrise::Agent.new { |task| processed << task.title }
    worker_class = Class.new do
      include EminenceGrise::Sidekiq
      eminence_grise_agent { agent }
    end

    count = worker_class.new.perform(
      "id" => "task-1",
      "title" => "Fix specs"
    )

    expect(count).to eq(1)
    expect(processed).to eq(["Fix specs"])
  end

  it "accepts existing task payloads" do
    seen = nil
    task = EminenceGrise::Task.new(id: "task-1", title: "Fix specs")
    agent = EminenceGrise::Agent.new { |received| seen = received }
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
    end

    job_class.new.perform(task)

    expect(seen).to eq(task)
  end

  it "accepts symbol keys" do
    processed = []
    agent = EminenceGrise::Agent.new { |task| processed << [task.id, task.metadata] }
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
    end

    job_class.new.perform(id: "task-1", title: "Fix specs", metadata: { source: "admin" })

    expect(processed).to eq([["task-1", { source: "admin" }]])
  end

  it "raises a clear error when no agent is configured" do
    job_class = Class.new do
      include EminenceGrise::ActiveJob
    end

    expect do
      job_class.new.perform("id" => "task-1", "title" => "Fix specs")
    end.to raise_error(EminenceGrise::Jobs::ConfigurationError, /eminence_grise_agent must be configured/)
  end

  it "does not wait on retry_at by default" do
    retry_at = Time.now + 60
    agent = EminenceGrise::Agent.new do |_task|
      raise JobRetryAtError, retry_at
    end
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
    end

    expect do
      job_class.new.perform("id" => "task-1", "title" => "Fix specs")
    end.to raise_error(JobRetryAtError)
  end

  it "can wait on retry_at when configured" do
    retry_at = Time.now - 1
    attempts = 0
    agent = EminenceGrise::Agent.new do |_task|
      attempts += 1
      raise JobRetryAtError, retry_at if attempts == 1
    end
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
      eminence_grise_wait_on_retry_at true
    end

    count = job_class.new.perform("id" => "task-1", "title" => "Fix specs")

    expect(count).to eq(1)
    expect(attempts).to eq(2)
  end

  it "passes a configured logger to the runner" do
    logger = FakeJobLogger.new
    agent = EminenceGrise::Agent.new { |_task| }
    job_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
      eminence_grise_logger { logger }
    end

    job_class.new.perform("id" => "task-1", "title" => "Fix specs")

    expect(logger.messages).to include_message(:info, /task started id=task-1/)
    expect(logger.messages).to include_message(:info, /task finished id=task-1/)
  end

  it "inherits agent configuration from a parent job class" do
    processed = []
    agent = EminenceGrise::Agent.new { |task| processed << task.id }
    parent_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
    end
    child_class = Class.new(parent_class)

    child_class.new.perform("id" => "task-1", "title" => "Fix specs")

    expect(processed).to eq(["task-1"])
  end

  it "inherits logger configuration from a parent job class" do
    logger = FakeJobLogger.new
    agent = EminenceGrise::Agent.new { |_task| }
    parent_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
      eminence_grise_logger { logger }
    end
    child_class = Class.new(parent_class)

    child_class.new.perform("id" => "task-1", "title" => "Fix specs")

    expect(logger.messages).to include_message(:info, /task started id=task-1/)
  end

  it "inherits retry configuration from a parent job class" do
    retry_at = Time.now - 1
    attempts = 0
    agent = EminenceGrise::Agent.new do |_task|
      attempts += 1
      raise JobRetryAtError, retry_at if attempts == 1
    end
    parent_class = Class.new do
      include EminenceGrise::ActiveJob
      eminence_grise_agent { agent }
      eminence_grise_wait_on_retry_at true
    end
    child_class = Class.new(parent_class)

    child_class.new.perform("id" => "task-1", "title" => "Fix specs")

    expect(attempts).to eq(2)
  end

  def include_message(level, pattern)
    satisfy do |messages|
      messages.any? { |message_level, message| message_level == level && message.match?(pattern) }
    end
  end
end
