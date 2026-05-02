# frozen_string_literal: true

require "time"
require_relative "agent_result"

module EminenceGrise
  class Runner
    class ResultHandler
      def initialize(queue:, logger: nil)
        @queue = queue
        @logger = logger
      end

      def call(result)
        return unless result.is_a?(AgentResult)

        raise failure_for(result) if result.failed?

        result.tasks.each do |task|
          @queue.push(task)
          @logger&.puts("enqueued #{task.id}: #{task.title}")
        end
      end

      private

      def failure_for(result)
        return result.output if result.output.is_a?(StandardError)

        RuntimeError.new(result.output || "agent returned failed result")
      end
    end

    def initialize(queue:, agent:, logger: nil, wait_on_retry_at: true, sleeper: Kernel.method(:sleep), clock: Time.method(:now))
      @queue = queue
      @agent = agent
      @logger = logger
      @wait_on_retry_at = wait_on_retry_at
      @sleeper = sleeper
      @clock = clock
      @result_handler = ResultHandler.new(queue: @queue, logger: @logger)
    end

    def run(max_tasks: nil)
      processed = 0

      while (task = @queue.pop)
        run_task(task)
        processed += 1

        break if max_tasks && processed >= max_tasks
      end

      processed
    end

    private

    def run_task(task)
      loop do
        @logger&.puts("starting #{task.id}: #{task.title}")
        result = @agent.call(task)
        @result_handler.call(result)
        @logger&.puts("finished #{task.id}: #{task.title}")
        return
      rescue StandardError => error
        raise unless wait_for_retry?(error)

        wait_until = error.retry_at
        seconds = [wait_until - @clock.call, 0].max
        @logger&.puts("waiting until #{wait_until.iso8601} before retrying #{task.id}: #{task.title}")
        @sleeper.call(seconds)
      end
    end

    def wait_for_retry?(error)
      @wait_on_retry_at && error.respond_to?(:retry_at) && error.retry_at
    end

  end
end
