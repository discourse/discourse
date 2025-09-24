# frozen_string_literal: true

describe "Admin Email Templates", type: :system do
  fab!(:admin)

  let(:email_templates_page) { PageObjects::Pages::AdminEmailTemplates.new }
  let(:composer) { PageObjects::Components::Composer.new(".email-template__body") }

  before { sign_in(admin) }

  it "forces markdown mode and doesn't allow the user to toggle the rich text editor" do
    email_templates_page.visit_template("user_notifications.account_exists")

    expect(composer).to have_markdown_editor_active
    expect(composer).to have_no_toggle_switch
  end

  it "can edit an email template" do
    email_templates_page.visit_template("user_notifications.account_exists")

    subject_text = "Modified test subject #{SecureRandom.hex(8)}"
    email_templates_page.edit_subject(subject_text)

    body_text =
      "This is a modified test body with some **markdown** formatting #{SecureRandom.hex(8)}"
    email_templates_page.edit_body(body_text)

    expect(email_templates_page).to have_preview_content(
      "This is a modified test body with some markdown formatting",
    )
    expect(page).to have_css(".d-editor-preview strong", text: "markdown")

    email_templates_page.save_changes
    expect(page).to have_css(".save-button .saved")

    email_templates_page.visit_template("user_notifications.account_exists")
    expect(email_templates_page).to have_subject_value(subject_text)
    expect(composer).to have_value(body_text)
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
end
