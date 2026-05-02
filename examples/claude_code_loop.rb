# frozen_string_literal: true

require "eminence_grise"

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and summarize the current architecture."
  )
])

claude = EminenceGrise::ClaudeCodeAgent.new(
  working_directory: File.expand_path("..", __dir__),
  output_format: "text"
)

agent = EminenceGrise::Agent.new do |task|
  result = claude.call(task)
  puts result.stdout unless result.stdout.empty?
  warn result.stderr unless result.stderr.empty?
  result
end

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console)
runner.run
