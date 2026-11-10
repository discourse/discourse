# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Data Tables" do
  fab!(:admin)

  let(:data_tables_page) { PageObjects::Pages::DiscourseWorkflows::DataTables.new }

  before { sign_in(admin) }

  it "shows existing data tables with their row counts" do
    data_table = Fabricate(:discourse_workflows_data_table, name: "users_cache")
    2.times { insert_data_table_row(data_table) }

    data_tables_page.visit_index

    expect(data_tables_page).to have_data_table("users_cache")
    expect(data_tables_page).to have_row_count_column
    expect(data_tables_page).to have_data_table_row_count(data_table, 2)
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

  describe "column menu" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        name: "contacts",
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end

    let(:dialog) { PageObjects::Components::Dialog.new }

    it "renames a column" do
      data_tables_page.visit_show(data_table.id)
      data_tables_page.click_column_menu_item("email", "rename_column")
      data_tables_page.fill_column_name("contact_email")

      expect(data_tables_page).to have_column_names(%w[contact_email score])
    end

    it "moves a column" do
      data_tables_page.visit_show(data_table.id)
      data_tables_page.click_column_menu_item("email", "move_column_right")

      expect(data_tables_page).to have_column_names(%w[score email])
    end

    it "deletes a column after confirmation" do
      data_tables_page.visit_show(data_table.id)
      data_tables_page.click_column_menu_item("email", "delete_column")
      dialog.click_danger

      expect(data_tables_page).to have_column_names(%w[score])
    end
  end
end
