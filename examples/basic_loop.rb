# frozen_string_literal: true

require "eminence_grise"

sandbox_directory = File.expand_path("../../eminence-grise-sandbox", __dir__)

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "sandbox-readme",
    title: "Improve the sandbox README",
    description: <<~TEXT,
      Use the sandbox repository as the target workspace:
      #{sandbox_directory}

      The sandbox can be modified unconditionally. Create or use the branch
      from task metadata, then update the README so it clearly explains that
      this repository is the disposable target for Eminence Grise agent tasks.
    TEXT
    metadata: {
      working_directory: sandbox_directory,
      branch: "biximilien/docs/sandbox-readme"
    }
  )
])

agent = EminenceGrise::Agent.new do |task|
  puts "Agent received: #{task.title}"
  puts "Working directory: #{task.metadata_value(:working_directory)}"
  puts "Branch: #{task.metadata_value(:branch)}"
  puts "Plan: #{task.description}"
end

runner = EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console)
runner.run
