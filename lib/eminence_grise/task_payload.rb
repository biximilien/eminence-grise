# frozen_string_literal: true

require_relative "task"

module EminenceGrise
  # Converts job and JSON payloads into {Task} objects.
  module TaskPayload
    module_function

    # @param payload [Task, Hash]
    # @return [Task]
    # @raise [ArgumentError] when payload is invalid
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

    # @api private
    def required_value_for(payload, key)
      value = value_for(payload, key)
      raise ArgumentError, "task payload must include #{key}" if value.nil?

      value
    end
    private_class_method :required_value_for

    # @api private
    def value_for(payload, key)
      payload.fetch(key) { payload.fetch(key.to_s, nil) }
    end
    private_class_method :value_for
  end
end
