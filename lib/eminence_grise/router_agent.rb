# frozen_string_literal: true

require_relative "agent_registry"

module EminenceGrise
  class RouterAgent
    def initialize(registry:, default: nil, &router)
      raise ArgumentError, "router agent requires a router block or default agent" unless router || default

      @registry = registry
      @default = default
      @router = router
    end

    def call(task)
      agent_name = route(task)
      agent = @registry.fetch(agent_name)
      agent.call(task)
    end

    private

    def route(task)
      (@router && @router.call(task)) || @default
    end
  end
end
