# frozen_string_literal: true

require_relative "../agents/result"
require_relative "../logging"

module EminenceGrise
  # Handles structured agent results for {Runner}.
  #
  # @api private
  class ResultHandler
    def initialize(queue:, logger: nil)
      @queue = queue
      @logger = Logging.coerce(logger)
    end

    # Handle an agent result.
    #
    # @param result [Object]
    # @return [void]
    def call(result)
      return unless result.is_a?(AgentResult)

      raise failure_for(result) if result.failed?

      result.tasks.each do |task|
        @queue.push(task)
        @logger.info("task enqueued id=#{task.id} title=#{task.title.inspect}")
      end
    end

    private

    def failure_for(result)
      return result.output if result.output.is_a?(StandardError)

      RuntimeError.new(result.output || "agent returned failed result")
    end
  end
end
