# frozen_string_literal: true

describe DiscourseDataExplorer::QueryUpdater do
  it "invalidates cached results only after the outer transaction commits" do
    query = Fabricate(:query)
    user = Fabricate(:admin)
    cached = { "columns" => ["value"], "rows" => [[1]] }
    DiscourseDataExplorer::QueryResultCache.write(query.id, user, {}, cached)

    DiscourseDataExplorer::Query.transaction do
      described_class.update(query:, query_params: { sql: "SELECT 2 AS value" })
      expect(DiscourseDataExplorer::QueryResultCache.read(query.id, user, {})).to include(cached)
    end
    expect(DiscourseDataExplorer::QueryResultCache.read(query.id, user, {})).to be_nil

    DiscourseDataExplorer::QueryResultCache.write(query.id, user, {}, cached)
    DiscourseDataExplorer::Query.transaction do
      described_class.update(query:, query_params: { sql: "SELECT 3 AS value" })
      raise ActiveRecord::Rollback
    end
    expect(query.reload.sql).to eq("SELECT 2 AS value")
    expect(DiscourseDataExplorer::QueryResultCache.read(query.id, user, {})).to include(cached)
  end
end
