# frozen_string_literal: true

module EminenceGrise
  # Registry of named specialist agents.
  class AgentRegistry
    def initialize
      @agents = {}
    end

    # Register an agent under a symbolic name.
    #
    # @param name [Symbol, String]
    # @param agent [#call]
    # @return [AgentRegistry]
    def register(name, agent)
      @agents[name.to_sym] = agent
      self
    end

    # Fetch a registered agent.
    #
    # @param name [Symbol, String]
    # @return [#call]
    # @raise [KeyError] when no agent has been registered for name
    def fetch(name)
      @agents.fetch(name.to_sym) do
        raise KeyError, "agent not registered: #{name}"
      end
    end

    # @param name [Symbol, String]
    # @return [Boolean]
    def key?(name)
      @agents.key?(name.to_sym)
    end

    # @return [Array<Symbol>]
    def names
      @agents.keys
    end
  end
end
