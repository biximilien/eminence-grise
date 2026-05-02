# frozen_string_literal: true

RSpec.describe EminenceGrise::TaskPayload do
  it "returns existing tasks unchanged" do
    task = EminenceGrise::Task.new(id: "task-1", title: "Fix specs")

    expect(described_class.call(task)).to eq(task)
  end

  it "converts string-key hash payloads to tasks" do
    task = described_class.call(
      "id" => "task-1",
      "title" => "Fix specs",
      "description" => "Run the suite.",
      "metadata" => { "source" => "admin" }
    )

    expect(task.id).to eq("task-1")
    expect(task.title).to eq("Fix specs")
    expect(task.description).to eq("Run the suite.")
    expect(task.metadata).to eq("source" => "admin")
  end

  it "converts symbol-key hash payloads to tasks" do
    task = described_class.call(
      id: "task-1",
      title: "Fix specs",
      description: "Run the suite.",
      metadata: { source: "admin" }
    )

    expect(task.id).to eq("task-1")
    expect(task.title).to eq("Fix specs")
    expect(task.description).to eq("Run the suite.")
    expect(task.metadata).to eq(source: "admin")
  end

  it "defaults optional description and metadata" do
    task = described_class.call(id: "task-1", title: "Fix specs")

    expect(task.description).to be_nil
    expect(task.metadata).to eq({})
  end

  it "rejects invalid payload types" do
    expect do
      described_class.call("task-1")
    end.to raise_error(ArgumentError, "task payload must be a Task or Hash")
  end

  it "requires id" do
    expect do
      described_class.call(title: "Fix specs")
    end.to raise_error(ArgumentError, "task payload must include id")
  end

  it "requires title" do
    expect do
      described_class.call(id: "task-1")
    end.to raise_error(ArgumentError, "task payload must include title")
  end

  it "requires metadata to be a hash" do
    expect do
      described_class.call(id: "task-1", title: "Fix specs", metadata: "admin")
    end.to raise_error(ArgumentError, "task metadata must be a Hash")
  end
end
