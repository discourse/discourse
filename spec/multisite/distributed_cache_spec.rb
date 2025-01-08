# frozen_string_literal: true

RSpec.describe "Multisite SiteSettings", type: :multisite do
  def cache(name, namespace: true)
    DistributedCache.new(name, namespace: namespace)
  end

  context "without namespace" do
    let(:cache1) { cache("test", namespace: false) }

    it "does leak state across multisite" do
      cache1["default"] = true

      expect(cache1.hash).to eq("default" => true)

      test_multisite_connection("second") do
        message =
          MessageBus
            .track_publish(DistributedCache::Manager::CHANNEL_NAME) { cache1["second"] = true }
            .first

        expect(message.data[:hash_key]).to eq("test")
        expect(message.data[:op]).to eq(:set)
        expect(message.data[:key]).to eq("second")
        expect(message.data[:value]).to eq(true)
        expect(cache1.hash).to eq("default" => true, "second" => true)
      end

      expect(cache1.hash).to eq("default" => true, "second" => true)
    end
  end

  context "with namespace" do
    let(:cache1) { cache("test", namespace: true) }

    it "does not leak state across multisite" do
      cache1["default"] = true

      expect(cache1.hash).to eq("default" => true)

      test_multisite_connection("second") do
        message =
          MessageBus
            .track_publish(DistributedCache::Manager::CHANNEL_NAME) { cache1["second"] = true }
            .first

        expect(message.data[:hash_key]).to eq("test")
        expect(message.data[:op]).to eq(:set)
        expect(message.data[:key]).to eq("second")
        expect(message.data[:value]).to eq(true)
        expect(cache1.hash).to eq("second" => true)
      end

      expect(cache1.hash).to eq("default" => true)
    end
  end
end
