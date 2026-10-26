# frozen_string_literal: true

describe "Admin Email Templates" do
  fab!(:admin)

  let(:email_templates_page) { PageObjects::Pages::AdminEmailTemplates.new }
  let(:composer) { PageObjects::Components::Composer.new(".email-template__body") }

  before { sign_in(admin) }

  it "lets the admin edit an email template in markdown and reload its saved content" do
    email_templates_page.visit_template("user_notifications.account_exists")

    aggregate_failures "markdown editor" do
      expect(composer).to have_markdown_editor_active
      expect(composer).to have_no_toggle_switch
    end

    subject_text = "Modified test subject #{SecureRandom.hex(8)}"
    email_templates_page.edit_subject(subject_text)

    body_text =
      "This is a modified test body with some **markdown** formatting #{SecureRandom.hex(8)}"
    email_templates_page.edit_body(body_text)

    aggregate_failures "markdown preview" do
      expect(email_templates_page).to have_preview_content(
        "This is a modified test body with some markdown formatting",
      )
      expect(page).to have_css(".d-editor-preview strong", text: "markdown")
    end

    email_templates_page.save_changes
    aggregate_failures "saved template" do
      expect(page).to have_css(".save-button .saved")
    end

    email_templates_page.visit_template("user_notifications.account_exists")
    aggregate_failures "persisted template" do
      expect(email_templates_page).to have_subject_value(subject_text)
      expect(composer).to have_value(body_text)
    end
  end

  it "shows link to site texts for template with multiple subjects" do
    email_templates_page.visit_template("system_messages.pending_users_reminder")
    expect(email_templates_page).to have_multiple_subjects_link(
      "#{Discourse.base_url}/admin/customize/site_texts?q=system_messages.pending_users_reminder",
    )
  end

  it "shows link to site texts for template with multiple bodies" do
    email_templates_page.visit_template("system_messages.reviewables_reminder")
    expect(email_templates_page).to have_multiple_bodies_link(
      "#{Discourse.base_url}/admin/customize/site_texts?q=system_messages.reviewables_reminder",
    )
  end

  it "shows interpolation keys for templates that have them" do
    email_templates_page.visit_template("user_notifications.admin_login")
    expect(email_templates_page).to have_interpolation_keys(
      %w[base_url email_prefix email_token site_name],
    )
  end

  it "does not show interpolation keys for templates without any" do
    email_templates_page.visit_template("system_messages.download_remote_images_disabled")
    expect(email_templates_page).to have_no_interpolation_keys
  end
end
