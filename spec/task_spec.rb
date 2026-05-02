# frozen_string_literal: true

RSpec.describe EminenceGrise::Task do
  it "reads symbol metadata values" do
    task = described_class.new(id: "task-1", title: "Route docs", metadata: { agent: :docs })

    expect(task.metadata_value(:agent)).to eq(:docs)
  end

  it "reads string metadata values with symbol keys" do
    task = described_class.new(id: "task-1", title: "Route docs", metadata: { "agent" => "docs" })

    expect(task.metadata_value(:agent)).to eq("docs")
  end

  it "prefers exact metadata keys" do
    task = described_class.new(
      id: "task-1",
      title: "Route docs",
      metadata: { agent: :symbol_agent, "agent" => "string_agent" }
    )

    expect(task.metadata_value(:agent)).to eq(:symbol_agent)
    expect(task.metadata_value("agent")).to eq("string_agent")
  end

  it "returns nil for missing metadata keys" do
    task = described_class.new(id: "task-1", title: "Route docs")

    expect(task.metadata_value(:agent)).to be_nil
  end
end
