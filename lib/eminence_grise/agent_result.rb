# frozen_string_literal: true

module EminenceGrise
  class AgentResult
    attr_reader :status, :output, :tasks, :metadata

    def self.complete(output = nil, tasks: [], metadata: {})
      new(status: :complete, output: output, tasks: tasks, metadata: metadata)
    end

    def self.split(tasks, output: nil, metadata: {})
      new(status: :split, output: output, tasks: tasks, metadata: metadata)
    end

    def self.delegated(task, to:, output: nil, metadata: {})
      routed_task = task.with_metadata(agent: to)
      new(status: :delegated, output: output, tasks: [routed_task], metadata: metadata.merge(agent: to))
    end

    def self.failed(error, metadata: {})
      new(status: :failed, output: error, tasks: [], metadata: metadata)
    end

    def initialize(status:, output: nil, tasks: [], metadata: {})
      @status = status
      @output = output
      @tasks = Array(tasks).freeze
      @metadata = metadata.freeze
      freeze
    end

    def failed?
      @status == :failed
    end
  end
end
