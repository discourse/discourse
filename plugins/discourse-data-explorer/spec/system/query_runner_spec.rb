# frozen_string_literal: true

RSpec.describe "Data explorer query runner" do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "group") }
  fab!(:group_user) { Fabricate(:group_user, user: admin, group: group) }

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  context "when navigating between queries" do
    fab!(:query_a) do
      Fabricate(:query, name: "Query A", sql: "SELECT * FROM users LIMIT 1", user: admin)
    end
    fab!(:query_b) do
      Fabricate(:query, name: "Query B", sql: "SELECT * FROM users LIMIT 1", user: admin)
    end

    it "clears results from a previously run query" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query_a.id}")
      find(".query-run .btn-primary").click
      expect(page).to have_css(".query-results .result-header")

      find(".back-button").click
      first("a[href='/admin/plugins/discourse-data-explorer/queries/#{query_b.id}']").click
      expect(page).to have_no_css(".query-results .result-header")
    end
  end

  context "with a query using a default param" do
    fab!(:query_1) do
      Fabricate(
        :query,
        name: "My default param query",
        description: "Test default param query",
        sql: "-- [params]\n-- string :limit = 42\n\nSELECT * FROM users LIMIT :limit",
        user: admin,
      )
    end
    fab!(:query_group_1) { Fabricate(:query_group, query: query_1, group: group) }

    it "pre-fills the field with the default param" do
      query_runner.visit_group_report("group", query_1.id)

      expect(query_runner).to have_param_field("limit", "42")
    end

    it "allows to edit custom name" do
      query_runner.visit_admin_query(query_1.id).run_query.click_edit_name
      query_runner.fill_query_name("My custom name edited").click_save_and_run

      expect(query_runner).to have_query_name("My custom name edited")
    end
  end

  context "with the old url format" do
    fab!(:query_1) do
      Fabricate(
        :query,
        name: "My query",
        description: "Test query",
        sql: "SELECT * FROM users",
        user: admin,
      )
    end

    it "redirects /explorer/queries/:id to the new url format" do
      visit("/admin/plugins/explorer/queries/#{query_1.id}")

      expect(page).to have_current_path(
        "/admin/plugins/discourse-data-explorer/queries/#{query_1.id}",
      )
    end

    it "redirects /explorer/queries to the new url format" do
      visit("/admin/plugins/explorer/queries")

      expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries")
    end

    it "redirects /explorer to the new url format" do
      visit("/admin/plugins/explorer")

      expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries")
    end
  end
end
