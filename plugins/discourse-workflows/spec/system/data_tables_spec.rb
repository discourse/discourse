# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Data Tables" do
  fab!(:admin)

  let(:data_tables_page) { PageObjects::Pages::DiscourseWorkflows::DataTables.new }

  before { sign_in(admin) }

  it "shows existing data tables" do
    data_table = Fabricate(:discourse_workflows_data_table, name: "users_cache")

    data_tables_page.visit_index

    expect(data_tables_page).to have_data_table("users_cache")
  end

  it "creates a new data table and navigates to its viewer" do
    data_tables_page.visit_index
    data_tables_page.click_add_data_table
    data_tables_page.fill_data_table_name("my_table")
    data_tables_page.submit_data_table_modal

    expect(data_tables_page).to have_viewer
  end

  it "adds a row to the data table" do
    data_table = Fabricate(:discourse_workflows_data_table, name: "events")

    data_tables_page.visit_show(data_table.id)
    data_tables_page.click_add_row

    expect(data_tables_page).to have_row(count: 1)
  end
end
