# frozen_string_literal: true

RSpec.describe "Signup with captcha" do
  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:captcha) { PageObjects::Components::Captcha.new }

  before do
    SiteSetting.enable_local_logins = true
    SiteSetting.discourse_captcha_enabled = true
  end

  context "when hCaptcha is configured" do
    before do
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
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
  end

  context "when reCaptcha is configured" do
    before do
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::RECAPTCHA
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
    before { SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::NONE }

    it "does not display any captcha widget" do
      signup_page.open
      expect(captcha).to have_no_hcaptcha_container
      expect(captcha).to have_no_recaptcha_container
    end
  end

  context "when captcha is disabled" do
    before do
      SiteSetting.discourse_captcha_enabled = false
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "test-key"
      SiteSetting.hcaptcha_secret_key = "test-secret"
    end

    it "does not display any captcha widget" do
      signup_page.open
      expect(captcha).to have_no_hcaptcha_container
      expect(captcha).to have_no_recaptcha_container
    end
  end

  context "when site requires login" do
    before do
      SiteSetting.login_required = true
      SiteSetting.discourse_captcha_provider = DiscourseHcaptcha::CaptchaProvider::HCAPTCHA
      SiteSetting.hcaptcha_site_key = "10000000-ffff-ffff-ffff-000000000001"
      SiteSetting.hcaptcha_secret_key = "0x0000000000000000000000000000000000000000"
    end

    it "displays the captcha widget on signup page" do
      signup_page.open
      expect(captcha).to have_hcaptcha_container
    end
  end
end
