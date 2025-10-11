# frozen_string_literal: true

describe "Admin Email Templates Page", type: :system do
  fab!(:admin)

  let(:email_templates_page) { PageObjects::Pages::AdminEmailTemplatesIndex.new }

  before { sign_in(admin) }

  it "navigates to the email template edit page when clicking the Edit button" do
    email_templates_page.visit

    email_templates_page.template("user_notifications.account_exists").edit_button.click

    expect(page).to have_current_path("/admin/email/templates/user_notifications.account_exists")
  end

  it "navigates to the email template edit page when clicking the template name" do
    email_templates_page.visit

    email_templates_page.template("user_notifications.account_exists").name_cell.click

    expect(page).to have_current_path("/admin/email/templates/user_notifications.account_exists")
  end

  describe "filter controls" do
    it "can find templates by name" do
      email_templates_page.visit

      email_templates_page.filter_controls.type_in_search("Account already")

      expect(email_templates_page).to have_exact_count_templates_shown(1)
      expect(
        email_templates_page.template("user_notifications.account_exists").name_cell.text.strip,
      ).to eq("Account already exists")
    end

    it "can find templates by id" do
      email_templates_page.visit

      email_templates_page.filter_controls.type_in_search("user_notifications.account_exists")

      expect(email_templates_page).to have_exact_count_templates_shown(1)
      expect(
        email_templates_page.template("user_notifications.account_exists").name_cell.text.strip,
      ).to eq("Account already exists")
    end

    it "can filter templates to only show overridden ones" do
      TranslationOverride.upsert!(
        I18n.locale,
        "user_notifications.user_replied_pm.text_body_template",
        "some new body",
      )
      email_templates_page.visit

      expect(email_templates_page.only_overridden_checkbox.checked?).to be_falsey

      email_templates_page.only_overridden_checkbox.click

      expect(email_templates_page).to have_exact_count_templates_shown(1)
      expect(email_templates_page.template("user_notifications.user_replied_pm")).to be_overridden
    end
  end
end
