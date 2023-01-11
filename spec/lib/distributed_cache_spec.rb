# frozen_string_literal: true

RSpec.describe DistributedCache do
  let(:cache) { described_class.new("mytest") }

  it "can defer_get_set" do
    messages =
      MessageBus.track_publish("/distributed_hash") { cache.defer_get_set("key") { "value" } }
    expect(messages.size).to eq(1)
    expect(cache["key"]).to eq("value")
  end

  it "works correctly for nil values" do
    block_called_counter = 0
    messages =
      MessageBus.track_publish("/distributed_hash") do
        2.times do
          cache.defer_get_set("key") do
            block_called_counter += 1
            nil
          end
        end
      end

    expect(block_called_counter).to eq(1)
    expect(messages.size).to eq(1)
    expect(cache["key"]).to eq(nil)
  end
end
