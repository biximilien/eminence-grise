# frozen_string_literal: true

require_relative "../memory_queue"
require_relative "../runner"
require_relative "../task"

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
        task = task_from(payload)
        queue = MemoryQueue.new([task])
        Runner.new(
          queue: queue,
          agent: @agent,
          logger: @logger,
          wait_on_retry_at: @wait_on_retry_at
        ).run(max_tasks: 1)
      end

      private

      def task_from(payload)
        return payload if payload.is_a?(Task)
        raise ArgumentError, "task payload must be a Task or Hash" unless payload.is_a?(Hash)

        metadata = value_for(payload, :metadata) || {}
        raise ArgumentError, "task metadata must be a Hash" unless metadata.is_a?(Hash)

        Task.new(
          id: required_value_for(payload, :id),
          title: required_value_for(payload, :title),
          description: value_for(payload, :description),
          metadata: metadata
        )
      end

      def required_value_for(payload, key)
        value = value_for(payload, key)
        raise ArgumentError, "task payload must include #{key}" if value.nil?

        value
      end

      def value_for(payload, key)
        payload.fetch(key) { payload.fetch(key.to_s, nil) }
      end
    end
  end
end
