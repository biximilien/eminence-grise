# frozen_string_literal: true

module EminenceGrise
  # Simple in-process FIFO task queue.
  #
  # This queue is useful for examples, tests, and single-process loops. Durable
  # queues can implement the same minimal `pop` and `push` boundary.
  class MemoryQueue
    # @param tasks [Array<Task>] initial queued tasks
    def initialize(tasks = [])
      @tasks = tasks.dup
    end

    # Append a task to the queue.
    #
    # @param task [Task]
    # @return [MemoryQueue]
    def push(task)
      @tasks << task
      self
    end

    # Pop the next task, or nil when the queue is empty.
    #
    # @return [Task, nil]
    def pop
      @tasks.shift
    end

    # @return [Boolean]
    def empty?
      @tasks.empty?
    end

    # @return [Integer]
    def size
      @tasks.size
    end
  end
end
