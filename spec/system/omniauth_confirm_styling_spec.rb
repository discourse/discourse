# frozen_string_literal: true

RSpec.describe "OmniAuth Confirm Page" do
  let(:omniauth_confirm_page) { PageObjects::Pages::OmniauthConfirm.new }

  before { SiteSetting.title = "My Awesome Community" }

  context "with Google OAuth" do
    before do
      SiteSetting.enable_google_oauth2_logins = true
      SiteSetting.google_oauth2_client_id = "fake_client_id"
      SiteSetting.google_oauth2_client_secret = "fake_secret"
    end

    it "displays the styled confirmation page with correct content" do
      omniauth_confirm_page.visit_provider("google_oauth2")

      expect(omniauth_confirm_page).to have_logo
      expect(omniauth_confirm_page).to have_card
      expect(omniauth_confirm_page).to have_title_for_provider("Google")
      expect(omniauth_confirm_page).to have_provider_info("Google")
      expect(omniauth_confirm_page).to have_continue_button
      expect(omniauth_confirm_page).to have_site_name_in_footer("My Awesome Community")
    end
  end

  context "with Discourse ID" do
    before do
      SiteSetting.discourse_id_client_id = SecureRandom.hex
      SiteSetting.discourse_id_client_secret = SecureRandom.hex
      SiteSetting.enable_discourse_id = true
    end

    it "displays the styled confirmation page with correct content" do
      omniauth_confirm_page.visit_provider("discourse_id")

      expect(omniauth_confirm_page).to have_logo
      expect(omniauth_confirm_page).to have_card
      expect(omniauth_confirm_page).to have_title_for_provider("Discourse ID")
      expect(omniauth_confirm_page).to have_provider_info("Discourse ID")
      expect(omniauth_confirm_page).to have_continue_button
      expect(omniauth_confirm_page).to have_site_name_in_footer("My Awesome Community")
    end
  end
end
