# frozen_string_literal: true

module EminenceGrise
  Task = Struct.new(:id, :title, :description, :metadata, keyword_init: true) do
    def initialize(id:, title:, description: nil, metadata: {})
      super
      self.metadata = metadata.freeze
      freeze
    end

    def with_metadata(additions)
      self.class.new(
        id: id,
        title: title,
        description: description,
        metadata: metadata.merge(additions)
      )
    end
  end
end
