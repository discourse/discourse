# frozen_string_literal: true

describe "Data explorer result caching" do
  fab!(:admin)

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  context "when viewing a query with cached results" do
    fab!(:query) { Fabricate(:query, name: "Cached query", sql: "SELECT 1 AS value", user: admin) }

    it "shows cached results and notice on page load" do
      # Run the query to populate the cache
      query_runner.visit_admin_query(query.id).run_query
      expect(query_runner).to have_result_header

      # Navigate away and back
      find(".query-edit .previous").click
      query_runner.visit_admin_query(query.id)

      # Cached results should be shown automatically
      expect(query_runner).to have_result_header
      expect(query_runner).to have_cached_result_notice
    end

    it "clears cached notice after a fresh run" do
      # Populate cache
      query_runner.visit_admin_query(query.id).run_query
      expect(query_runner).to have_result_header

      # Navigate away and back to see cached results
      find(".query-edit .previous").click
      query_runner.visit_admin_query(query.id)
      expect(query_runner).to have_cached_result_notice

      # Run again — fresh results should replace cached
      query_runner.run_query
      expect(query_runner).to have_result_header
      expect(query_runner).to have_no_cached_result_notice
    end
  end

  context "when viewing a query without cached results" do
    fab!(:query) { Fabricate(:query, name: "Fresh query", sql: "SELECT 2 AS value", user: admin) }

    it "does not show cached notice" do
      query_runner.visit_admin_query(query.id)

      expect(query_runner).to have_no_cached_result_notice
      expect(page).to have_no_css(".query-results .result-header")
    end
  end

  context "when results have chartable data" do
    fab!(:query) do
      Fabricate(
        :query,
        name: "Chartable query",
        sql:
          "SELECT date_trunc('day', created_at) AS day, COUNT(*) AS count FROM users GROUP BY day ORDER BY day LIMIT 10",
        user: admin,
      )
    end

    it "shows both chart and table" do
      query_runner.visit_admin_query(query.id).run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_chart
      expect(query_runner).to have_result_table
    end
  end

  context "when results are not chartable" do
    fab!(:query) do
      Fabricate(:query, name: "Text query", sql: "SELECT username FROM users LIMIT 3", user: admin)
    end

    it "shows table without chart" do
      query_runner.visit_admin_query(query.id).run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_no_chart
      expect(query_runner).to have_result_table
    end
  end
end
