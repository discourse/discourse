# frozen_string_literal: true

describe DiscourseDataExplorer::ResultCache do
  fab!(:query) { Fabricate(:query, sql: "SELECT 1 as value") }

  let(:result_json) { { "success" => true, "columns" => ["value"], "rows" => [[1]] } }

  after { described_class.invalidate(query) }

  describe ".params_hash" do
    it "returns nil for blank params" do
      expect(described_class.params_hash(nil)).to be_nil
      expect(described_class.params_hash({})).to be_nil
    end

    it "returns a consistent hash for the same params" do
      params = { "foo" => "1", "bar" => "2" }
      expect(described_class.params_hash(params)).to eq(described_class.params_hash(params))
    end

    it "returns the same hash regardless of key order" do
      hash1 = described_class.params_hash({ "b" => "2", "a" => "1" })
      hash2 = described_class.params_hash({ "a" => "1", "b" => "2" })
      expect(hash1).to eq(hash2)
    end

    it "returns different hashes for different params" do
      hash1 = described_class.params_hash({ "foo" => "1" })
      hash2 = described_class.params_hash({ "foo" => "2" })
      expect(hash1).not_to eq(hash2)
    end
  end

  describe ".set and .get" do
    it "stores and retrieves cached results" do
      freeze_time

      described_class.set(query, nil, result_json)

      cached = described_class.get(query)
      expect(cached["result"]).to eq(result_json)
      expect(cached["cached_at"]).to eq(Time.now.iso8601)
    end

    it "separates cache entries by params" do
      params_a = { "limit" => "10" }
      params_b = { "limit" => "20" }
      result_a = { "rows" => [[10]] }
      result_b = { "rows" => [[20]] }

      described_class.set(query, params_a, result_a)
      described_class.set(query, params_b, result_b)

      expect(described_class.get(query, params_a)["result"]).to eq(result_a)
      expect(described_class.get(query, params_b)["result"]).to eq(result_b)
    end

    it "always updates the base key as latest result" do
      params = { "num" => "10" }
      described_class.set(query, params, result_json)

      cached = described_class.get(query)
      expect(cached["result"]).to eq(result_json)
    end

    it "returns nil when no cache exists" do
      expect(described_class.get(query)).to be_nil
    end

    it "expires after TTL" do
      described_class.set(query, nil, result_json)

      key = described_class.cache_key(query.id, nil)
      ttl = Discourse.redis.ttl(key)
      expect(ttl).to be > 0
      expect(ttl).to be <= described_class::TTL
    end

    it "does not cache results exceeding MAX_CACHE_SIZE" do
      large_result = { "rows" => [["x" * 1024]] * 200 }
      result = described_class.set(query, nil, large_result)

      expect(result).to eq(false)
      expect(described_class.get(query)).to be_nil
    end

    it "returns true when caching succeeds" do
      result = described_class.set(query, nil, result_json)
      expect(result).to eq(true)
    end
  end

  describe ".invalidate" do
    it "clears all cached results for a query" do
      described_class.set(query, { "a" => "1" }, result_json)
      described_class.set(query, { "b" => "2" }, result_json)
      described_class.set(query, nil, result_json)

      described_class.invalidate(query)

      expect(described_class.get(query, { "a" => "1" })).to be_nil
      expect(described_class.get(query, { "b" => "2" })).to be_nil
      expect(described_class.get(query)).to be_nil
    end

    it "does not affect other queries" do
      other_query = Fabricate(:query, sql: "SELECT 2 as value")
      described_class.set(query, nil, result_json)
      described_class.set(other_query, nil, result_json)

      described_class.invalidate(query)

      expect(described_class.get(query)).to be_nil
      expect(described_class.get(other_query)).to be_present

      described_class.invalidate(other_query)
    end
  end
end
