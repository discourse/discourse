# frozen_string_literal: true

RSpec.describe "Signup with captcha" do
  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:captcha) { PageObjects::Components::Captcha.new }

  before do
    SiteSetting.enable_local_logins = true
    SiteSetting.discourse_captcha_enabled = true
  end

  context "with hCaptcha", allow_network: %w[hcaptcha.com *.hcaptcha.com] do
    before do
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "10000000-ffff-ffff-ffff-000000000001"
      SiteSetting.hcaptcha_secret_key = "0x0000000000000000000000000000000000000000"
    end

    it "displays the hCaptcha widget on signup page" do
      signup_page.open
      expect(captcha).to have_hcaptcha_container
    end

    it "loads the hCaptcha iframe" do
      signup_page.open
      expect(captcha).to have_hcaptcha_widget
    end

    it "does not display reCaptcha container" do
      signup_page.open
      expect(captcha).to have_no_recaptcha_container
    end

    context "when site requires login" do
      before { SiteSetting.login_required = true }

      it "displays the captcha widget on signup page" do
        signup_page.open
        expect(captcha).to have_hcaptcha_container
      end
    end

    context "when submitting signup without completing captcha" do
      it "shows error message when captcha is not completed" do
        signup_page
          .open
          .fill_email("test@example.com")
          .fill_username("testuser")
          .fill_password("supersecurepassword")
        expect(signup_page).to have_valid_fields

        signup_page.click_create_account

        expect(signup_page).to have_flash_message(I18n.t("js.discourse_captcha.missing_token"))
      end
    end

    context "when captcha is disabled" do
      before { SiteSetting.discourse_captcha_enabled = false }

      it "does not display any captcha widget" do
        signup_page.open
        expect(captcha).to have_no_hcaptcha_container
        expect(captcha).to have_no_recaptcha_container
      end
    end
  end

  context "with reCaptcha", allow_network: %w[www.google.com www.gstatic.com] do
    before do
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA
      SiteSetting.recaptcha_site_key = "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI"
      SiteSetting.recaptcha_secret_key = "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe"
    end

    it "displays the reCaptcha widget on signup page" do
      signup_page.open
      expect(captcha).to have_recaptcha_container
    end

    it "loads the reCaptcha iframe" do
      signup_page.open
      expect(captcha).to have_recaptcha_widget
    end

    it "does not display hCaptcha container" do
      signup_page.open
      expect(captcha).to have_no_hcaptcha_container
    end
  end

  context "when captcha provider is none" do
    before { SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::NONE }

    it "does not display any captcha widget" do
      signup_page.open
      expect(captcha).to have_no_hcaptcha_container
      expect(captcha).to have_no_recaptcha_container
    end
  end
end
