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
    it "lets user configure logos and other branding" do
      wizard_page.go_to_step("branding")
      expect(wizard_page).to be_on_step("branding")
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
    end
  end
end
