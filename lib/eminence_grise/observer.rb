# frozen_string_literal: true

require "time"

module EminenceGrise
  # Structured event emitted by runners, agents, and workflows.
  Event = Struct.new(:type, :task_id, :timestamp, :data, keyword_init: true) do
    def initialize(type:, task_id: nil, timestamp: Time.now, data: {})
      super(type: type, task_id: task_id, timestamp: timestamp, data: data.freeze)
      freeze
    end

    def to_h
      {
        type: type,
        task_id: task_id,
        timestamp: timestamp,
        data: data
      }
    end
  end

  # Callable observer backed by a block.
  class Observer
    def self.coerce(observer)
      return NullObserver.new unless observer
      return observer if observer.respond_to?(:call)

      raise ArgumentError, "observer must respond to #call"
    end

    def initialize(&block)
      @block = block || ->(_event) {}
    end

    def call(event)
      @block.call(event)
    end
  end

  # Default observer that ignores all events.
  class NullObserver
    def call(_event)
      nil
    end
  end
end
