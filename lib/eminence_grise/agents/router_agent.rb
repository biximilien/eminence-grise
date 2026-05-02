# frozen_string_literal: true

require_relative "registry"

module EminenceGrise
  class RouterAgent
    class RoutingError < StandardError; end

    def initialize(registry:, default: nil, &router)
      raise ArgumentError, "router agent requires a router block or default agent" unless router || default

      @registry = registry
      @default = default
      @router = router
    end

    def call(task)
      agent_name = route(task)
      raise RoutingError, "no route for task #{task.id}: #{task.title}" unless agent_name
      raise RoutingError, "unknown route #{agent_name.inspect} for task #{task.id}: #{task.title}" unless @registry.key?(agent_name)

      agent = @registry.fetch(agent_name)
      agent.call(task)
    end

    private

    def route(task)
      (@router && @router.call(task)) || @default
    end
  end
end
