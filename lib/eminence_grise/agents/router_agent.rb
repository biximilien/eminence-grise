# frozen_string_literal: true

require_relative "registry"

module EminenceGrise
  # Dispatches tasks to agents registered in an {AgentRegistry}.
  #
  # @example
  #   router = EminenceGrise::RouterAgent.new(registry: registry, default: :code) do |task|
  #     task.metadata_value(:agent)
  #   end
  class RouterAgent
    # Raised when a task cannot be routed to a registered agent.
    class RoutingError < StandardError; end

    # @param registry [AgentRegistry]
    # @param default [Symbol, String, nil] fallback agent name
    # @yieldparam task [Task]
    # @yieldreturn [Symbol, String, nil] registered agent name
    # @raise [ArgumentError] when neither router block nor default is provided
    def initialize(registry:, default: nil, &router)
      raise ArgumentError, "router agent requires a router block or default agent" unless router || default

      @registry = registry
      @default = default
      @router = router
    end

    # Route and process a task.
    #
    # @param task [Task]
    # @return [Object]
    # @raise [RoutingError] when no route exists or the route is unknown
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
