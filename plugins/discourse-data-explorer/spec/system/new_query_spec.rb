# frozen_string_literal: true

describe "Data explorer new query" do
  fab!(:admin)

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  it "navigates to the new query page from the index" do
    visit("/admin/plugins/discourse-data-explorer/queries")
    find(".d-page-subheader .btn-primary").click
    expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries/new")
  end

  it "creates a query with name and description" do
    query_runner
      .visit_new_query
      .fill_new_query_name("Test Query")
      .fill_new_query_description("A test description")
      .submit_new_query

    query = DiscourseDataExplorer::Query.last
    expect(query.name).to eq("Test Query")
    expect(query.description).to eq("A test description")

    expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries/#{query.id}")
    expect(query_runner).to have_query_name("Test Query")
    expect(query_runner).to have_query_description("A test description")
  end

  it "creates a query with name only" do
    query_runner.visit_new_query.fill_new_query_name("Name Only Query").submit_new_query

    query = DiscourseDataExplorer::Query.last
    expect(query.name).to eq("Name Only Query")

    expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries/#{query.id}")
    expect(query_runner).to have_query_name("Name Only Query")
  end
end
