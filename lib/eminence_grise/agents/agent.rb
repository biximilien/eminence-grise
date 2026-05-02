# frozen_string_literal: true

module EminenceGrise
  class Agent
    def initialize(&handler)
      raise ArgumentError, "agent requires a handler block" unless handler

      @handler = handler
    end

    def call(task)
      @handler.call(task)
    end
  end
end
