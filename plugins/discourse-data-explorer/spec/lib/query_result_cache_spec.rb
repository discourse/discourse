# frozen_string_literal: true

describe DiscourseDataExplorer::QueryResultCache do
  fab!(:query) { Fabricate(:query, sql: "SELECT 1") }

  let(:params_hash) { { "limit" => "10", "name" => "test" } }
  let(:result_json) do
    {
      "success" => true,
      "columns" => %w[id],
      "rows" => [[1], [2]],
      "result_count" => 2,
      "duration" => 1.5,
      "params" => params_hash,
      "relations" => {
      },
      "colrender" => {
      },
      "default_limit" => 1000,
    }
  end

  after { described_class.invalidate(query.id) }

  describe ".write and .read" do
    it "stores and retrieves results" do
      described_class.write(query.id, params_hash, result_json)
      cached = described_class.read(query.id, params_hash)

      expect(cached["success"]).to eq(true)
      expect(cached["rows"]).to eq([[1], [2]])
      expect(cached["cached_at"]).to be_present
    end

    it "returns nil on cache miss" do
      expect(described_class.read(query.id, params_hash)).to be_nil
    end

    it "skips write when result exceeds max size" do
      large_result = result_json.merge("rows" => [["x" * 200_000]])

      expect(described_class.write(query.id, params_hash, large_result)).to eq(false)
      expect(described_class.read(query.id, params_hash)).to be_nil
    end

    it "sets a TTL on the cache key" do
      described_class.write(query.id, params_hash, result_json)
      key = described_class.cache_key(query.id, params_hash)
      ttl = Discourse.redis.ttl(key)

      expect(ttl).to be > 0
      expect(ttl).to be <= described_class::CACHE_TTL
    end

    it "does not add new cache entries once the per-query limit is reached" do
      (described_class::MAX_CACHE_ENTRIES + 1).times do |i|
        described_class.write(query.id, { "value" => i.to_s }, result_json)
      end

      oldest_key = described_class.cache_key(query.id, { "value" => "0" })
      overflow_key =
        described_class.cache_key(query.id, { "value" => described_class::MAX_CACHE_ENTRIES.to_s })

      expect(Discourse.redis.get(oldest_key)).to be_present
      expect(Discourse.redis.get(overflow_key)).to be_nil
      expect(Discourse.redis.zcard(described_class.cache_index_key(query.id))).to eq(
        described_class::MAX_CACHE_ENTRIES,
      )
    end
  end

  describe ".cache_key" do
    it "produces the same key regardless of param order" do
      key_a = described_class.cache_key(query.id, { "b" => "2", "a" => "1" })
      key_b = described_class.cache_key(query.id, { "a" => "1", "b" => "2" })

      expect(key_a).to eq(key_b)
    end

    it "produces different keys for different params" do
      key_a = described_class.cache_key(query.id, { "a" => "1" })
      key_b = described_class.cache_key(query.id, { "a" => "2" })

      expect(key_a).not_to eq(key_b)
    end

    it "handles nil params" do
      key = described_class.cache_key(query.id, nil)
      expect(key).to include("data_explorer:result:#{query.id}:")
    end
  end

  describe ".invalidate" do
    it "removes all cached results for a query" do
      described_class.write(query.id, { "a" => "1" }, result_json)
      described_class.write(query.id, { "b" => "2" }, result_json)

      described_class.invalidate(query.id)

      expect(described_class.read(query.id, { "a" => "1" })).to be_nil
      expect(described_class.read(query.id, { "b" => "2" })).to be_nil
    end

    it "does not affect other queries" do
      other_query = Fabricate(:query, sql: "SELECT 2")

      described_class.write(query.id, params_hash, result_json)
      described_class.write(other_query.id, params_hash, result_json)

      described_class.invalidate(query.id)

      expect(described_class.read(query.id, params_hash)).to be_nil
      expect(described_class.read(other_query.id, params_hash)).to be_present
    end
  end
end
