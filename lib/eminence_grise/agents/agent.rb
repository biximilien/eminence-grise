# frozen_string_literal: true

module EminenceGrise
  # Callable agent backed by a Ruby block.
  #
  # @example
  #   agent = EminenceGrise::Agent.new do |task|
  #     puts "Working on #{task.title}"
  #   end
  class Agent
    # @yieldparam task [Task]
    # @raise [ArgumentError] when no handler block is provided
    def initialize(&handler)
      raise ArgumentError, "agent requires a handler block" unless handler

      @handler = handler
    end

    # Process a task.
    #
    # @param task [Task]
    # @return [Object]
    def call(task)
      @handler.call(task)
    end
  end
end
