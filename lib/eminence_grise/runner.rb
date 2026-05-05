# frozen_string_literal: true

require "time"
require_relative "logging"
require_relative "result_handler"

module EminenceGrise
  # Sequential task runner.
  #
  # The runner pops tasks from a queue, calls an agent, and lets
  # {ResultHandler} enqueue any structured follow-up tasks.
  class Runner
    # @param queue [#pop, #push] task source
    # @param agent [#call] callable that processes a task
    # @param logger [Logger, #puts, nil] optional logger
    # @param wait_on_retry_at [Boolean] whether retryable CLI errors should sleep and retry
    # @param sleeper [#call] injectable sleep callable for tests
    # @param clock [#call] injectable clock callable for tests
    def initialize(queue:, agent:, logger: nil, wait_on_retry_at: true, sleeper: Kernel.method(:sleep), clock: Time.method(:now))
      @queue = queue
      @agent = agent
      @logger = Logging.coerce(logger)
      @wait_on_retry_at = wait_on_retry_at
      @sleeper = sleeper
      @clock = clock
      @result_handler = ResultHandler.new(queue: @queue, logger: @logger)
    end

    # Process tasks until the queue is drained or max_tasks is reached.
    #
    # @param max_tasks [Integer, nil]
    # @return [Integer] number of tasks processed
    # @raise [StandardError] re-raises agent failures and failed agent results
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
        @logger.info("task started id=#{task.id} title=#{task.title.inspect}")
        result = @agent.call(task)
        @result_handler.call(result)
        @logger.info("task finished id=#{task.id} title=#{task.title.inspect}")
        return
      rescue StandardError => error
        unless wait_for_retry?(error)
          @logger.error("task failed id=#{task.id} title=#{task.title.inspect} error=#{error.message.inspect}")
          raise
        end

        wait_until = error.retry_at
        seconds = [wait_until - @clock.call, 0].max
        @logger.warn("task retry waiting id=#{task.id} title=#{task.title.inspect} retry_at=#{wait_until.iso8601}")
        @sleeper.call(seconds)
      end
    end

    def wait_for_retry?(error)
      @wait_on_retry_at && error.respond_to?(:retry_at) && error.retry_at
    end

  end
end
