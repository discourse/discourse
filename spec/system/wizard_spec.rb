# frozen_string_literal: true

describe "Wizard", type: :system do
  fab!(:admin)

  let(:wizard_page) { PageObjects::Pages::Wizard.new }

  before { sign_in(admin) }

  it "successfully goes through every step of the wizard" do
    visit("/wizard")
    expect(wizard_page).to be_on_step("introduction")
    wizard_page.fill_field("text", "title", "My Test Site")
    wizard_page.go_to_next_step
    expect(wizard_page).to be_on_step("privacy")
    wizard_page.go_to_next_step
    expect(wizard_page).to be_on_step("styling")
    wizard_page.go_to_next_step
    expect(wizard_page).to be_on_step("ready")
    wizard_page.click_configure_more
    expect(wizard_page).to be_on_step("branding")
    wizard_page.go_to_next_step
    expect(wizard_page).to be_on_step("corporate")
    wizard_page.click_jump_in
    expect(page).to have_current_path("/latest")
  end

  describe "Wizard Step: Privacy" do
    it "lets user configure member access" do
      wizard_page.go_to_step("privacy")
      expect(SiteSetting.login_required).to eq(false)
      expect(SiteSetting.invite_only).to eq(false)
      expect(SiteSetting.must_approve_users).to eq(false)

      expect(wizard_page.privacy_step).to have_selected_choice("login-required", "public")
      expect(wizard_page.privacy_step).to have_selected_choice("invite-only", "sign_up")
      expect(wizard_page.privacy_step).to have_selected_choice("must-approve-users", "no")

      wizard_page.privacy_step.select_access_option("login-required", "private")
      wizard_page.privacy_step.select_access_option("invite-only", "invite_only")
      wizard_page.privacy_step.select_access_option("must-approve-users", "yes")

      wizard_page.go_to_next_step

      expect(wizard_page).to be_on_step("styling")
      expect(SiteSetting.login_required).to eq(true)
      expect(SiteSetting.invite_only).to eq(true)
      expect(SiteSetting.must_approve_users).to eq(true)

      wizard_page.go_to_step("privacy")

      expect(wizard_page.privacy_step).to have_selected_choice("login-required", "private")
      expect(wizard_page.privacy_step).to have_selected_choice("invite-only", "invite_only")
      expect(wizard_page.privacy_step).to have_selected_choice("must-approve-users", "yes")
    end
  end

  describe "Wizard Step: Branding" do
    let(:file_path_1) { file_from_fixtures("logo.png", "images").path }
    let(:file_path_2) { file_from_fixtures("logo.jpg", "images").path }

    it "lets user configure logos" do
      wizard_page.go_to_step("branding")
      expect(wizard_page).to be_on_step("branding")
      attach_file(file_path_1) { wizard_page.branding_step.click_upload_button("logo") }
      expect(wizard_page.branding_step).to have_upload("logo")
      attach_file(file_path_2) { wizard_page.branding_step.click_upload_button("logo-small") }
      expect(wizard_page.branding_step).to have_upload("logo-small")
      wizard_page.go_to_next_step
      expect(wizard_page).to be_on_step("corporate")

      expect(SiteSetting.logo).to eq(Upload.find_by(original_filename: File.basename(file_path_1)))
      expect(SiteSetting.logo_small).to eq(
        Upload.find_by(original_filename: File.basename(file_path_2)),
      )
    end
  end

  describe "Wizard Step: Styling" do
    it "lets user configure styling including fonts and colors" do
      wizard_page.go_to_step("styling")
      expect(wizard_page).to be_on_step("styling")

      wizard_page.styling_step.select_color_palette_option("Dark")
      wizard_page.styling_step.select_body_font_option("lato")
      wizard_page.styling_step.select_heading_font_option("merriweather")
      wizard_page.styling_step.select_homepage_style_option("hot")

      wizard_page.go_to_next_step
      expect(wizard_page).to be_on_step("ready")

      expect(Theme.find_default.color_scheme_id).to eq(
        ColorScheme.find_by(base_scheme_id: "Dark", via_wizard: true).id,
      )
      expect(SiteSetting.base_font).to eq("lato")
      expect(SiteSetting.heading_font).to eq("merriweather")
      expect(SiteSetting.homepage).to eq("hot")

      wizard_page.go_to_step("styling")

      expect(wizard_page.styling_step).to have_selected_color_palette("Dark")
      expect(wizard_page.styling_step).to have_selected_body_font("lato")
      expect(wizard_page.styling_step).to have_selected_heading_font("merriweather")
      expect(wizard_page.styling_step).to have_selected_homepage_style("hot")
    end
  end

  describe "Wizard Step: Ready" do
    it "redirects to latest" do
      wizard_page.go_to_step("ready")
      wizard_page.click_jump_in

      expect(page).to have_current_path("/latest")
    end

    it "redirects to admin guide when bootstrap mode is enabled" do
      topic = Fabricate(:topic_with_op, title: "Admin Getting Started Guide")
      SiteSetting.bootstrap_mode_enabled = true
      SiteSetting.admin_quick_start_topic_id = topic.id

      wizard_page.go_to_step("ready")
      wizard_page.click_jump_in

      expect(page).to have_current_path(topic.url)
    end
  end

  describe "Wizard Step: Corporate" do
    it "lets user configure corporate including governing law and city for disputes" do
      wizard_page.go_to_step("corporate")
      expect(wizard_page).to be_on_step("corporate")
      wizard_page.fill_field("text", "company-name", "ACME")
      wizard_page.fill_field("text", "governing-law", "California")
      wizard_page.fill_field("text", "contact-url", "https://ac.me")
      wizard_page.fill_field("text", "city-for-disputes", "San Francisco")
      wizard_page.fill_field("text", "contact-email", "coyote@ac.me")
      wizard_page.click_jump_in
      expect(page).to have_current_path("/latest")

      expect(SiteSetting.company_name).to eq("ACME")
      expect(SiteSetting.governing_law).to eq("California")
      expect(SiteSetting.city_for_disputes).to eq("San Francisco")
      expect(SiteSetting.contact_url).to eq("https://ac.me")
      expect(SiteSetting.contact_email).to eq("coyote@ac.me")

      wizard_page.go_to_step("corporate")
      expect(wizard_page).to have_field_with_value("text", "company-name", "ACME")
      expect(wizard_page).to have_field_with_value("text", "governing-law", "California")
      expect(wizard_page).to have_field_with_value("text", "contact-url", "https://ac.me")
      expect(wizard_page).to have_field_with_value("text", "city-for-disputes", "San Francisco")
      expect(wizard_page).to have_field_with_value("text", "contact-email", "coyote@ac.me")
    end
  end
end
