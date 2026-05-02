# frozen_string_literal: true

require "eminence_grise"

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "task-1",
    title: "Create a project README",
    description: "Draft a concise README for the project."
  ),
  EminenceGrise::Task.new(
    id: "task-2",
    title: "Add tests",
    description: "Create a first focused test suite."
  )
])

agent = EminenceGrise::Agent.new do |task|
  puts "Agent received: #{task.title}"
  puts "Plan: #{task.description}"
end

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: $stdout)
runner.run
