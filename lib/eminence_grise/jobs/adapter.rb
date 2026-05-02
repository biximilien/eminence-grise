# frozen_string_literal: true

require_relative "../memory_queue"
require_relative "../runner"
require_relative "../task_payload"

module EminenceGrise
  module Jobs
    class ConfigurationError < StandardError; end

    class Adapter
      def initialize(agent:, logger: nil, wait_on_retry_at: false)
        @agent = agent
        @logger = logger
        @wait_on_retry_at = wait_on_retry_at
      end

      def call(payload)
        task = TaskPayload.call(payload)
        queue = MemoryQueue.new([task])
        Runner.new(
          queue: queue,
          agent: @agent,
          logger: @logger,
          wait_on_retry_at: @wait_on_retry_at
        ).run(max_tasks: 1)
      end
    end
  end
end
