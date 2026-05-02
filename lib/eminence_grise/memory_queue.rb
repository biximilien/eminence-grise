# frozen_string_literal: true

module EminenceGrise
  class MemoryQueue
    def initialize(tasks = [])
      @tasks = tasks.dup
    end

    def push(task)
      @tasks << task
      self
    end

    def pop
      @tasks.shift
    end

    def empty?
      @tasks.empty?
    end

    def size
      @tasks.size
    end
  end
end
