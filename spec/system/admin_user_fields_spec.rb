# frozen_string_literal: true

describe "Admin User Fields", type: :system do
  fab!(:current_user, :admin)

  before { sign_in(current_user) }

  let(:user_fields_page) { PageObjects::Pages::AdminUserFields.new }
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  it "correctly saves user fields" do
    user_fields_page.visit
    expect(page_header).to be_visible
    user_fields_page.add_field(name: "Occupation", description: "What you do for work")

    expect(user_fields_page).to have_user_field("Occupation")

    user_fields_page.refresh

    expect(user_fields_page).to have_user_field("Occupation")
  end

  it "displays an error when missing required fields" do
    user_fields_page.visit

    user_fields_page.add_field(name: "Occupation", description: "")

    expect(user_fields_page.form.field(:description)).to have_errors("Required")
  end

  it "makes sure new required fields are editable after signup" do
    user_fields_page.visit
    user_fields_page.click_add_field

    expect(page_header).to be_hidden

    form = page.find(".user-field")
    editable_label = I18n.t("admin_js.admin.user_fields.editable.title")

    user_fields_page.choose_requirement("for_all_users")

    expect(form).to have_field(editable_label, checked: true, disabled: true)

    user_fields_page.choose_requirement("optional")

    expect(form).to have_field(editable_label, checked: true, disabled: false)
  end

  it "makes sure fields are available on signup when they have to" do
    user_fields_page.visit
    user_fields_page.click_add_field

    expect(page_header).to be_hidden

    form = page.find(".user-field")
    show_on_signup_label = I18n.t("admin_js.admin.user_fields.show_on_signup.title")

    user_fields_page.choose_requirement("for_all_users")

    expect(form).to have_field(show_on_signup_label, checked: true, disabled: true)

    user_fields_page.choose_requirement("on_signup")

    expect(form).to have_field(show_on_signup_label, checked: true, disabled: true)

    user_fields_page.choose_requirement("optional")

    expect(form).to have_field(show_on_signup_label, checked: true, disabled: false)

    user_fields_page.unselect_preference("editable")

    expect(form).to have_field(show_on_signup_label, checked: true, disabled: true)
  end

  it "requires confirmation when applying required fields retroactively" do
    user_fields_page.visit
    user_fields_page.click_add_field

    form = page.find(".user-field")

    form.find(".user-field-name").fill_in(with: "Favourite Pokémon")
    form.find(".user-field-desc").fill_in(with: "Hint: It's Mudkip")

    user_fields_page.choose_requirement("for_all_users")

    form.find(".btn-primary").click

    expect(page).to have_text(I18n.t("admin_js.admin.user_fields.requirement.confirmation"))
  end

  context "when editing an existing user field" do
    fab!(:user_field) { Fabricate(:user_field, requirement: "for_all_users") }

    it "does not require confirmation if the field already applies to all users" do
      user_fields_page.visit
      user_fields_page.click_edit

      form = page.find(".user-field")

      form.find(".user-field-name").fill_in(with: "Favourite Transformer")

      expect(page_header).to be_hidden

      form.find(".btn-primary").click

      expect(page).to have_no_text(I18n.t("admin_js.admin.user_fields.requirement.confirmation"))
    end
  end
end
