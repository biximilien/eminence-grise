# frozen_string_literal: true

require "eminence_grise"

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and summarize the current architecture in README.md."
  )
])

agent = EminenceGrise::CodexAgent.new(
  working_directory: File.expand_path("..", __dir__),
  sandbox: "workspace-write",
  approval_policy: "never"
)

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: $stdout)
runner.run
