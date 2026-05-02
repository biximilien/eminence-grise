# frozen_string_literal: true

require_relative "../memory_queue"
require_relative "../runner"
require_relative "../task_payload"

module EminenceGrise
  # Namespace for optional job framework integrations.
  module Jobs
    # Raised when a job integration is missing required configuration.
    class ConfigurationError < StandardError; end

    # Runs one task payload through a configured agent.
    #
    # @api private
    class Adapter
      def initialize(agent:, logger: nil, wait_on_retry_at: false)
        @agent = agent
        @logger = logger
        @wait_on_retry_at = wait_on_retry_at
      end

      # Process one task payload.
      #
      # @param payload [Task, Hash]
      # @return [Integer] number of tasks processed
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
