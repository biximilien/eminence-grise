# frozen_string_literal: true

module EminenceGrise
  # Immutable unit of work processed by a runner.
  #
  # @example
  #   task = EminenceGrise::Task.new(
  #     id: "task-1",
  #     title: "Fix failing specs",
  #     description: "Run the suite and repair failures.",
  #     metadata: { agent: :code }
  #   )
  Task = Struct.new(:id, :title, :description, :metadata, keyword_init: true) do
    # @param id [String] stable task identifier
    # @param title [String] short human-readable task title
    # @param description [String, nil] optional task details
    # @param metadata [Hash] routing or workflow metadata
    def initialize(id:, title:, description: nil, metadata: {})
      super
      self.metadata = metadata.freeze
      freeze
    end

    # Return a copy of the task with merged metadata.
    #
    # @param additions [Hash] metadata values to merge
    # @return [Task]
    def with_metadata(additions)
      self.class.new(
        id: id,
        title: title,
        description: description,
        metadata: metadata.merge(additions)
      )
    end

    # Read a metadata value by symbol or string key.
    #
    # Exact keys win when both symbol and string forms exist.
    #
    # @param key [Symbol, String] metadata key
    # @return [Object, nil]
    def metadata_value(key)
      return metadata[key] if metadata.key?(key)

      alternate_key = case key
                      when Symbol then key.to_s
                      when String then key.to_sym
                      else return nil
                      end
      metadata[alternate_key]
    end
  end
end
