# frozen_string_literal: true

describe DiscourseDataExplorer::QueryRunner do
  fab!(:admin)

  fab!(:query) { Fabricate(:query, sql: "SELECT 1 AS value", user: admin) }

  fab!(:query_with_params) do
    Fabricate(
      :query,
      sql: "-- [params]\n-- int :limit = 10\n\nSELECT 1 AS value LIMIT :limit",
      user: admin,
    )
  end

  fab!(:query_with_internal_params) do
    Fabricate(
      :query,
      sql: "-- [params]\n-- current_user_id :me\n\nSELECT id FROM users WHERE id = :me",
      user: admin,
    )
  end

  after do
    described_class.invalidate(query.id)
    described_class.invalidate(query_with_params.id)
    described_class.invalidate(query_with_internal_params.id)
  end

  describe ".run" do
    it "runs the query and returns results" do
      result = described_class.run(query, nil, current_user: admin)

      expect(result[:success]).to eq(true)
      expect(result[:columns]).to include("value")
      expect(result[:rows]).to be_present
    end

    it "caches the result after execution" do
      described_class.run(query, nil, current_user: admin)

      cached = described_class.cached_result(query, nil)
      expect(cached).to be_present
      expect(cached["success"]).to eq(true)
    end

    it "does not cache when explain is true" do
      described_class.run(query, nil, current_user: admin, explain: true)

      expect(described_class.cached_result(query, nil)).to be_nil
    end

    it "does not cache queries with internal params" do
      described_class.run(query_with_internal_params, nil, current_user: admin)

      expect(described_class.cached_result(query_with_internal_params, nil)).to be_nil
    end

    it "returns error info when query fails" do
      bad_query = Fabricate(:query, sql: "SELECT * FROM nonexistent_table_xyz")
      result = described_class.run(bad_query, nil, current_user: admin)

      expect(result[:error]).to be_present
    end
  end

  describe ".cached_result" do
    it "returns nil when no cache exists" do
      expect(described_class.cached_result(query, nil)).to be_nil
    end

    it "returns cached result after execute" do
      described_class.run(query, nil, current_user: admin)
      cached = described_class.cached_result(query, nil)

      expect(cached["cached_at"]).to be_present
      expect(cached["rows"]).to be_present
    end

    it "returns nil for queries with internal params" do
      expect(described_class.cached_result(query_with_internal_params, nil)).to be_nil
    end

    it "resolves URL params when present" do
      described_class.run(query_with_params, '{"limit":"5"}', current_user: admin)

      cached = described_class.cached_result(query_with_params, '{"limit":"5"}')
      expect(cached).to be_present

      cached_default = described_class.cached_result(query_with_params, nil)
      expect(cached_default).to be_nil
    end

    it "falls back to default params when no URL params" do
      described_class.run(query_with_params, '{"limit":"10"}', current_user: admin)

      cached = described_class.cached_result(query_with_params, nil)
      expect(cached).to be_present
    end

    it "returns cached result when run was called with null params" do
      described_class.run(query_with_params, "null", current_user: admin)

      cached = described_class.cached_result(query_with_params, nil)
      expect(cached).to be_present
    end

    it "handles malformed JSON params gracefully" do
      expect(described_class.cached_result(query, "not-json")).to be_nil
    end
  end

  describe ".run" do
    it "does not cache when a non-default limit is used" do
      described_class.run(query, nil, current_user: admin, limit: 1)

      expect(described_class.cached_result(query, nil)).to be_nil
    end

    it "caches when using the default limit" do
      described_class.run(
        query,
        nil,
        current_user: admin,
        limit: SiteSetting.data_explorer_query_result_limit,
      )

      expect(described_class.cached_result(query, nil)).to be_present
    end
  end

  describe ".invalidate" do
    it "removes all cached results for a query" do
      described_class.run(query, nil, current_user: admin)
      expect(described_class.cached_result(query, nil)).to be_present

      described_class.invalidate(query.id)
      expect(described_class.cached_result(query, nil)).to be_nil
    end
  end
end
