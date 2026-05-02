# frozen_string_literal: true

require "eminence_grise"

registry = EminenceGrise::AgentRegistry.new

registry.register(:docs, EminenceGrise::Agent.new do |task|
  puts "Docs agent: #{task.title}"
end)

registry.register(:code, EminenceGrise::Agent.new do |task|
  puts "Code agent: #{task.title}"
end)

router = EminenceGrise::RouterAgent.new(registry: registry, default: :code) do |task|
  task.metadata[:agent]
end

planner = EminenceGrise::Agent.new do |task|
  if task.metadata[:agent]
    router.call(task)
  else
    EminenceGrise::AgentResult.split([
      EminenceGrise::Task.new(
        id: "#{task.id}-code",
        title: "Implement #{task.title}",
        metadata: { agent: :code }
      ),
      EminenceGrise::Task.new(
        id: "#{task.id}-docs",
        title: "Document #{task.title}",
        metadata: { agent: :docs }
      )
    ])
  end
end

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(id: "feature", title: "persistent queues")
])

runner = EminenceGrise::Runner.new(queue: queue, agent: planner, logger: $stdout)
runner.run
