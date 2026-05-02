# frozen_string_literal: true

module EminenceGrise
  # Structured result returned by agents that want to influence the queue.
  #
  # Plain agent return values are treated as completed work with no follow-up.
  # Return an AgentResult to split, delegate, or fail work explicitly.
  class AgentResult
    # Valid result statuses.
    VALID_STATUSES = [:complete, :delegated, :failed, :split].freeze

    attr_reader :status, :output, :tasks, :metadata

    # Mark work complete and optionally enqueue follow-up tasks.
    #
    # @param output [Object, nil]
    # @param tasks [Array<Task>]
    # @param metadata [Hash]
    # @return [AgentResult]
    def self.complete(output = nil, tasks: [], metadata: {})
      new(status: :complete, output: output, tasks: tasks, metadata: metadata)
    end

    # Split work into multiple follow-up tasks.
    #
    # @param tasks [Array<Task>]
    # @param output [Object, nil]
    # @param metadata [Hash]
    # @return [AgentResult]
    def self.split(tasks, output: nil, metadata: {})
      new(status: :split, output: output, tasks: tasks, metadata: metadata)
    end

    # Delegate a task to a named agent by setting task metadata.
    #
    # @param task [Task]
    # @param to [Symbol, String] registered agent name
    # @param output [Object, nil]
    # @param metadata [Hash]
    # @return [AgentResult]
    def self.delegated(task, to:, output: nil, metadata: {})
      routed_task = task.with_metadata(agent: to)
      new(status: :delegated, output: output, tasks: [routed_task], metadata: metadata.merge(agent: to))
    end

    # Mark work as failed.
    #
    # @param error [String, StandardError]
    # @param metadata [Hash]
    # @return [AgentResult]
    def self.failed(error, metadata: {})
      new(status: :failed, output: error, tasks: [], metadata: metadata)
    end

    # @param status [Symbol]
    # @param output [Object, nil]
    # @param tasks [Array<Task>]
    # @param metadata [Hash]
    # @raise [ArgumentError] when status is not valid
    def initialize(status:, output: nil, tasks: [], metadata: {})
      raise ArgumentError, "unknown agent result status: #{status.inspect}" unless VALID_STATUSES.include?(status)

      @status = status
      @output = output
      @tasks = Array(tasks).freeze
      @metadata = metadata.freeze
      freeze
    end

    # @return [Boolean]
    def failed?
      @status == :failed
    end
  end
end
