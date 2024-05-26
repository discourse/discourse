# frozen_string_literal: true

describe "Admin User Fields", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  let(:user_fields_page) { PageObjects::Pages::AdminUserFields.new }

  it "correctly saves user fields" do
    user_fields_page.visit
    user_fields_page.add_field(name: "Occupation", description: "What you do for work")

    expect(user_fields_page).to have_user_field("Occupation")

    user_fields_page.refresh

    expect(user_fields_page).to have_user_field("Occupation")
  end

  it "displays an error when missing required fields" do
    user_fields_page.visit

    user_fields_page.add_field(name: "Occupation", description: "")

    expect(user_fields_page).to have_text(/Description can't be blank/)
  end
end
