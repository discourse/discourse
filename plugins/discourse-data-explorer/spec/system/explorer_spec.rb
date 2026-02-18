# frozen_string_literal: true

RSpec.describe "Explorer", type: :system do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "group") }
  fab!(:group_user) { Fabricate(:group_user, user: admin, group: group) }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
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
      visit("/g/group/reports/#{query_1.id}")

      expect(page).to have_field("limit", with: 42)
    end

    it "allows to edit custom name" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query_1.id}")
      find(".query-run .btn-primary").click
      find(".edit-query-name").click
      find(".name-text-field input").fill_in(with: "My custom name edited")
      find(".btn-primary").click
      find("button span", text: "Save Changes and Run").click
      expect(page.find(".name h1")).to have_content("My custom name edited")
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

    it "redirects to the new url format" do
      visit("/admin/plugins/explorer/?id=#{query_1.id}")

      expect(page).to have_current_path(
        "/admin/plugins/discourse-data-explorer/queries/#{query_1.id}",
      )
    end

    it "redirects to the new url format with params" do
      visit("/admin/plugins/explorer/?id=#{query_1.id}&params=%7B%22limit%22%3A%2210%22%7D")

      expect(page).to have_current_path(
        "/admin/plugins/discourse-data-explorer/queries/#{query_1.id}?params=%7B%22limit%22%3A%2210%22%7D",
      )
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
      visit(
        "/admin/plugins/discourse-data-explorer/queries/#{q2.id}?params=%7B\"groups\"%3A\"admins%2Ctrust_level_1\"%7D",
      )
      find(".query-run .btn-primary").click

      expect(page).to have_css(".query-results .result-header")

      expect(page).to have_css(
        ".query-results tbody tr:nth-child(1) td:nth-child(2)",
        text: "admins",
      )
      expect(page).to have_css(
        ".query-results tbody tr:nth-child(2) td:nth-child(2)",
        text: "trust_level_1",
      )
    end
  end

  context "with a current_user_id param" do
    fab!(:query) { Fabricate(:query, name: "My current user query", sql: <<~SQL, user: admin) }
          -- [params]
          -- current_user_id :me
          SELECT id, username FROM users WHERE id = :me
        SQL

    it "auto-injects the current user's id without showing an input field" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")

      expect(page).to have_no_css(".query-params")
      find(".query-run .btn-primary").click

      expect(page).to have_css(".query-results .result-header")
      expect(page).to have_css(".query-results tbody tr", count: 1)
      expect(page).to have_css(".query-results tbody td", text: admin.username)
    end
  end
end
