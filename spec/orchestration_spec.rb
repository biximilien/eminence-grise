# frozen_string_literal: true

RSpec.describe "agent orchestration" do
  it "lets an agent split a task into follow-up tasks" do
    queue = EminenceGrise::MemoryQueue.new([
      EminenceGrise::Task.new(id: "feature", title: "Build feature")
    ])
    processed = []
    agent = EminenceGrise::Agent.new do |task|
      processed << task.id

      if task.id == "feature"
        EminenceGrise::AgentResult.split([
          EminenceGrise::Task.new(id: "feature-docs", title: "Write docs"),
          EminenceGrise::Task.new(id: "feature-specs", title: "Add specs")
        ])
      end
    end

    count = EminenceGrise::Runner.new(queue: queue, agent: agent).run

    expect(count).to eq(3)
    expect(processed).to eq(["feature", "feature-docs", "feature-specs"])
  end

  it "lets an agent delegate a task to a specialist through task metadata" do
    original = EminenceGrise::Task.new(id: "review", title: "Review changes")
    result = EminenceGrise::AgentResult.delegated(original, to: :reviewer)

    expect(result.status).to eq(:delegated)
    expect(result.tasks.first.metadata).to include(agent: :reviewer)
  end

  it "routes tasks to registered specialist agents" do
    registry = EminenceGrise::AgentRegistry.new
    registry.register(:docs, EminenceGrise::Agent.new { |task| "docs: #{task.title}" })
    registry.register(:coder, EminenceGrise::Agent.new { |task| "code: #{task.title}" })

    router = EminenceGrise::RouterAgent.new(registry: registry, default: :coder) do |task|
      task.metadata[:agent]
    end

    docs_task = EminenceGrise::Task.new(id: "docs", title: "README", metadata: { agent: :docs })
    code_task = EminenceGrise::Task.new(id: "code", title: "Runner")

    expect(router.call(docs_task)).to eq("docs: README")
    expect(router.call(code_task)).to eq("code: Runner")
  end
end
