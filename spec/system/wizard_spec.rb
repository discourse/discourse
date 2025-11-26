# frozen_string_literal: true

describe "Wizard", type: :system do
  fab!(:admin)

  let(:wizard_page) { PageObjects::Pages::Wizard.new }

  before { sign_in(admin) }

  it "successfully completes the setup wizard" do
    visit("/wizard")
    expect(wizard_page).to be_on_step("setup")
    wizard_page.fill_field("text", "title", "My Test Site")
    wizard_page.select_dropdown_option("default-locale", "en")
    wizard_page.click_jump_in
    expect(page).to have_current_path("/")
  end

  describe "Setup step" do
    it "lets user configure site settings including member access" do
      wizard_page.go_to_step("setup")
      expect(SiteSetting.login_required).to eq(false)
      expect(SiteSetting.invite_only).to eq(false)
      expect(SiteSetting.must_approve_users).to eq(false)

      expect(wizard_page.privacy_step).to have_selected_choice("login-required", "public")
      expect(wizard_page.privacy_step).to have_selected_choice("invite-only", "sign_up")
      expect(wizard_page.privacy_step).to have_selected_choice("must-approve-users", "no")

      wizard_page.fill_field("text", "title", "My Test Site")
      wizard_page.privacy_step.select_access_option("login-required", "private")
      wizard_page.privacy_step.select_access_option("invite-only", "invite_only")
      wizard_page.privacy_step.select_access_option("must-approve-users", "yes")

      wizard_page.click_jump_in

      expect(SiteSetting.login_required).to eq(true)
      expect(SiteSetting.invite_only).to eq(true)
      expect(SiteSetting.must_approve_users).to eq(true)
    end

    it "redirects to homepage when completed" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "My Test Site")
      wizard_page.click_jump_in

      expect(page).to have_current_path("/")
    end

    it "redirects to homepage even when bootstrap mode is enabled" do
      topic = Fabricate(:topic_with_op, title: "Admin Getting Started Guide")
      SiteSetting.bootstrap_mode_enabled = true
      SiteSetting.admin_quick_start_topic_id = topic.id

      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "My Test Site")
      wizard_page.click_jump_in
      expect(page).to have_current_path("/")
    end

    it "prevents submission when title is empty" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "")
      wizard_page.click_jump_in

      expect(wizard_page).to be_on_step("setup")
      expect(page).to have_css(".wizard-container__field.text-title.invalid")
    end

    it "prevents submission when title is 'Discourse'" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "Discourse")
      wizard_page.click_jump_in

      expect(wizard_page).to be_on_step("setup")
      expect(page).to have_css(".wizard-container__field.text-title.invalid")
    end
  end
end
