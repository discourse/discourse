# frozen_string_literal: true

describe "Admin Email Templates Page" do
  fab!(:admin)

  let(:email_templates_page) { PageObjects::Pages::AdminEmailTemplatesIndex.new }

  before { sign_in(admin) }

  it "lets the admin open a template from its Edit button and name" do
    email_templates_page.visit

    email_templates_page.template("user_notifications.account_exists").edit_button.click

    aggregate_failures "Edit button destination" do
      expect(page).to have_current_path("/admin/email/templates/user_notifications.account_exists")
    end

    page.go_back

    email_templates_page.template("user_notifications.account_exists").name_cell.click

    aggregate_failures "template name destination" do
      expect(page).to have_current_path("/admin/email/templates/user_notifications.account_exists")
    end
  end

  describe "filter controls" do
    it "lets the admin find a template by its name and identifier" do
      email_templates_page.visit

      email_templates_page.filter_controls.type_in_search("Account already")

      aggregate_failures "template name search" do
        expect(email_templates_page).to have_exact_count_templates_shown(1)
        expect(
          email_templates_page.template("user_notifications.account_exists").name_cell.text.strip,
        ).to eq("Account already exists")
      end

      email_templates_page.filter_controls.type_in_search("user_notifications.account_exists")

      aggregate_failures "template identifier search" do
        expect(email_templates_page).to have_exact_count_templates_shown(1)
        expect(
          email_templates_page.template("user_notifications.account_exists").name_cell.text.strip,
        ).to eq("Account already exists")
      end
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
