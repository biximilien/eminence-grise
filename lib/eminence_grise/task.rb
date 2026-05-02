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
