# frozen_string_literal: true

RSpec.describe EminenceGrise::Observer do
  it "calls the configured block with events" do
    seen = []
    observer = described_class.new { |event| seen << event }
    event = EminenceGrise::Event.new(type: "test.event", task_id: "one", data: { value: 1 })

    observer.call(event)

    expect(seen).to eq([event])
    expect(event.to_h).to include(type: "test.event", task_id: "one", data: { value: 1 })
  end

  it "coerces nil to a no-op observer" do
    expect(EminenceGrise::Observer.coerce(nil).call(EminenceGrise::Event.new(type: "test"))).to be_nil
  end
end
