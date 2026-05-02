# frozen_string_literal: true

require "eminence_grise"

task = EminenceGrise::Task.new(
  id: "TICK-123",
  title: "Build the cool new feature",
  description: <<~TEXT,
    Implement the requested feature using the repository's existing patterns.

    Development workflow:
    - Create or use the feature branch from metadata when appropriate.
    - Keep changes focused on this ticket.
    - Run the relevant tests.
    - Prepare a conventional commit message.
    - Do not commit, push, open a PR, or merge unless explicitly instructed.
  TEXT
  metadata: {
    ticket: "TICK-123",
    branch: "biximilien/feature/TICK-123-my-cool-new-feature",
    commit_style: "conventional",
    pull_request: true
  }
)

agent = EminenceGrise::Agent.new do |received_task|
  puts "Would hand task #{received_task.id} to a coding agent."
  puts "Title: #{received_task.title}"
  puts "Branch: #{received_task.metadata[:branch]}"
  puts "Commit style: #{received_task.metadata[:commit_style]}"
  puts "PR expected: #{received_task.metadata[:pull_request]}"
  puts
  puts received_task.description
end

queue = EminenceGrise::MemoryQueue.new([task])
runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console)
runner.run
