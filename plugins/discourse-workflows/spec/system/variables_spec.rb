# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Variables" do
  fab!(:admin)

  let(:variables_page) { PageObjects::Pages::DiscourseWorkflows::Variables.new }

  before { sign_in(admin) }

  it "shows existing variables" do
    Fabricate(
      :discourse_workflows_variable,
      key: "API_BASE_URL",
      value: "https://example.com",
      created_by: admin,
    )

    variables_page.visit_index

    expect(variables_page).to have_variable("API_BASE_URL")
    expect(variables_page).to have_variable_creator(admin.username)
  end

  it "creates a new variable" do
    variables_page.visit_index
    variables_page.click_add_variable
    variables_page.fill_variable_key("MY_SECRET_KEY")
    variables_page.fill_variable_value("secret_value")
    variables_page.submit_variable_modal

    expect(variables_page).to have_variable("MY_SECRET_KEY")
  end
end
