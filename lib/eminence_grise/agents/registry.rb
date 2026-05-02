# frozen_string_literal: true

module EminenceGrise
  class AgentRegistry
    def initialize
      @agents = {}
    end

    def register(name, agent)
      @agents[name.to_sym] = agent
      self
    end

    def fetch(name)
      @agents.fetch(name.to_sym) do
        raise KeyError, "agent not registered: #{name}"
      end
    end

    def key?(name)
      @agents.key?(name.to_sym)
    end

    def names
      @agents.keys
    end
  end
end
