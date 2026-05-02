# frozen_string_literal: true

require_relative "task"

module EminenceGrise
  module TaskPayload
    module_function

    def call(payload)
      return payload if payload.is_a?(Task)
      raise ArgumentError, "task payload must be a Task or Hash" unless payload.is_a?(Hash)

      metadata = value_for(payload, :metadata) || {}
      raise ArgumentError, "task metadata must be a Hash" unless metadata.is_a?(Hash)

      Task.new(
        id: required_value_for(payload, :id),
        title: required_value_for(payload, :title),
        description: value_for(payload, :description),
        metadata: metadata
      )
    end

    def required_value_for(payload, key)
      value = value_for(payload, key)
      raise ArgumentError, "task payload must include #{key}" if value.nil?

      value
    end
    private_class_method :required_value_for

    def value_for(payload, key)
      payload.fetch(key) { payload.fetch(key.to_s, nil) }
    end
    private_class_method :value_for
  end
end
