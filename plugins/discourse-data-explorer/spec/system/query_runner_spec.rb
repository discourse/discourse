# frozen_string_literal: true

RSpec.describe "Data explorer query runner", type: :system do
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

      find(".query-edit .previous").click
      find("a[href='/admin/plugins/discourse-data-explorer/queries/#{query_b.id}']").click
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

  context "with a group_list param" do
    fab!(:q2) do
      Fabricate(
        :query,
        name: "My query with group_list",
        description: "Test group_list query",
        sql:
          "-- [params]\n-- group_list :groups\n\nSELECT g.id,g.name FROM groups g WHERE g.name IN(:groups) ORDER BY g.name ASC",
        user: admin,
      )
    end

    it "supports setting a group_list param" do
      query_runner.visit_admin_query(
        q2.id,
        query_string: "params=%7B\"groups\"%3A\"admins%2Ctrust_level_1\"%7D",
      ).run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_result_cell_at(1, 2, text: "admins")
      expect(query_runner).to have_result_cell_at(2, 2, text: "trust_level_1")
    end
  end

  context "with a current_user_id param" do
    fab!(:query) { Fabricate(:query, name: "My current user query", sql: <<~SQL, user: admin) }
          -- [params]
          -- current_user_id :me
          SELECT id, username FROM users WHERE id = :me
        SQL

    it "auto-injects the current user's id without showing an input field" do
      query_runner.visit_admin_query(query.id)

      expect(query_runner).to have_no_params
      query_runner.run_query

      expect(query_runner).to have_result_header
      expect(query_runner).to have_result_row_count(1)
      expect(query_runner).to have_result_cell(admin.username)
    end
  end
end
