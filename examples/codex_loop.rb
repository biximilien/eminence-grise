# frozen_string_literal: true

require "eminence_grise"

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and summarize the current architecture in README.md."
  )
])

codex = EminenceGrise::CodexAgent.new(
  working_directory: File.expand_path("..", __dir__),
  sandbox: "workspace-write",
  approval_policy: "never"
)

agent = EminenceGrise::Agent.new do |task|
  result = codex.call(task)
  puts result.stdout unless result.stdout.empty?
  warn result.stderr unless result.stderr.empty?
  result
end

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console)
runner.run
