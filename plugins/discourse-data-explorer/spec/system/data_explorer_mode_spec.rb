# frozen_string_literal: true

RSpec.describe "Data explorer mode" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, name: "Test Query", sql: "SELECT 1 AS value", user: admin) }

  let(:index_page) { PageObjects::Pages::DataExplorerIndex.new }
  let(:query_page) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  context "when mode is disabled" do
    before { SiteSetting.data_explorer_mode = "disabled" }

    it "shows query list without links or write actions" do
      index_page.visit

      expect(index_page).to have_query_row(query)
      expect(index_page).to have_no_query_link(query)
      expect(index_page).to have_no_create_button
      expect(index_page).to have_no_import_button
      expect(index_page).to have_no_groups_column
      expect(index_page).to have_no_edit_row_button
    end

    it "redirects to index when visiting query details" do
      page.visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")

      expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries")
    end
  end
end
