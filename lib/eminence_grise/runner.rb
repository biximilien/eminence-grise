# frozen_string_literal: true

module EminenceGrise
  class Runner
    def initialize(queue:, agent:, logger: nil)
      @queue = queue
      @agent = agent
      @logger = logger
    end

    def run(max_tasks: nil)
      processed = 0

      while (task = @queue.pop)
        @logger&.puts("starting #{task.id}: #{task.title}")
        @agent.call(task)
        processed += 1
        @logger&.puts("finished #{task.id}: #{task.title}")

        break if max_tasks && processed >= max_tasks
      end

      processed
    end
  end
end
