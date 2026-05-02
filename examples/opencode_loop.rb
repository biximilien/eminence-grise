# frozen_string_literal: true

require "eminence_grise"

$stdout.sync = true
$stderr.sync = true

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Inspect the project",
    description: "Read the repository and print a short architecture summary. Do not modify files."
  )
])

agent = EminenceGrise::OpenCodeAgent.new(
  working_directory: Dir.pwd,
  stream: true
)

runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  logger: EminenceGrise::Logging.console,
  wait_on_retry_at: false
)

begin
  runner.run
rescue EminenceGrise::CliAgent::ExecutionError => error
  warn error.message
  exit 1
end
