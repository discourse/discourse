# frozen_string_literal: true

RSpec.describe "Data explorer query editor resizing" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, name: "Resize", sql: "SELECT 1", user: admin) }

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  # Narrow enough for the stacked layout, where the panes are content-sized and a
  # short floor clips them. Wide, they have a fixed height and cannot overflow.
  def in_the_stacked_layout(&block)
    resize_window(width: 500, height: 900, &block)
  end

  def shrink_hard
    query_runner.resize_panes_by(-400)
    # Asserted through a retry: the drag bypasses Capybara's settle wait.
    try_until_success { expect(query_runner.pane_overflow).to eq(0) }
  end

  it "does not shrink the panes past the content they clip" do
    in_the_stacked_layout do
      query_runner.visit_admin_query(query.id)
      expect(page).to have_css(".query-editor .panels-flex")

      shrink_hard
    end
  end

  it "does not shrink past the shorter content left when the schema is hidden" do
    in_the_stacked_layout do
      query_runner.visit_admin_query(query.id)
      expect(page).to have_css(".query-editor .panels-flex")
      query_runner.collapse_schema
      expect(page).to have_css(".query-editor.no-schema")

      shrink_hard
    end
  end

  it "asks less of the layout once the schema is out of it" do
    in_the_stacked_layout do
      query_runner.visit_admin_query(query.id)
      expect(page).to have_css(".query-editor .panels-flex")
      with_schema = query_runner.pane_floor

      query_runner.collapse_schema
      expect(page).to have_css(".query-editor.no-schema")

      # Stacked, the floor is what the panes rest at, not just a drag limit. The
      # taller figure would leave the editor standing in space it cannot fill.
      expect(query_runner.pane_floor).to be < with_schema
    end
  end

  it "follows the schema appearing after the panes were first measured without it" do
    in_the_stacked_layout do
      query_runner.visit_admin_query(query.id)
      query_runner.collapse_schema
      expect(page).to have_css(".query-editor.no-schema")

      # Revisited so the editor is built with the schema already hidden. Only
      # this order leaves a captured floor too low for the content that follows.
      query_runner.visit_admin_query(query.id)
      expect(page).to have_css(".query-editor.no-schema")
      query_runner.expand_schema
      expect(page).to have_no_css(".query-editor.no-schema")

      shrink_hard
    end
  end
end
