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

  it "makes sure new required fields are editable after signup" do
    user_fields_page.visit

    page.find(".user-fields .btn-primary").click

    form = page.find(".user-field")
    editable_label = I18n.t("admin_js.admin.user_fields.editable.title")

    user_fields_page.choose_requirement("for_all_users")

    expect(form).to have_field(editable_label, checked: true, disabled: true)

    user_fields_page.choose_requirement("optional")

    expect(form).to have_field(editable_label, checked: false, disabled: false)
  end

  it "requires confirmation when applying required fields retroactively" do
    user_fields_page.visit

    page.find(".user-fields .btn-primary").click

    form = page.find(".user-field")

    form.find(".user-field-name").fill_in(with: "Favourite Pokémon")
    form.find(".user-field-desc").fill_in(with: "Hint: It's Mudkip")

    user_fields_page.choose_requirement("for_all_users")

    form.find(".btn-primary").click

    expect(page).to have_text(I18n.t("admin_js.admin.user_fields.requirement.confirmation"))
  end
end
