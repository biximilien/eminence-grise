# frozen_string_literal: true

require "eminence_grise"

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and summarize the current architecture."
  )
])

agent = EminenceGrise::OpenCodeAgent.new(
  working_directory: File.expand_path("..", __dir__),
  stream: true
)

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console)
runner.run
