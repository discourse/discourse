# frozen_string_literal: true

RSpec.describe "Signup with captcha" do
  include ThemeScreenshotMarker
  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:code_signup) { PageObjects::Pages::CodeSignup.new }
  let(:captcha) { PageObjects::Components::Captcha.new }

  before do
    SiteSetting.enable_local_logins = true
    SiteSetting.discourse_captcha_enabled = true

    # Most examples exercise the password form, so keep the code option unavailable.
    SiteSetting.enable_local_logins_via_code = false
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

    context "with code-based signup" do
      before do
        SiteSetting.enable_local_logins_via_code = true
        Jobs.run_immediately!
      end

      it "shows the hCaptcha widget when choosing a username after email verification" do
        signup_page.open
        find(".code-login-form__email-step input[type='email']").fill_in(with: "test@example.com")
        find(".code-login-form__continue").click

        expect(page).to have_css(".code-login-form__code-step")
        expect(captcha).to have_no_hcaptcha_container

        code = ActionMailer::Base.deliveries.last.subject[/(\d{6})/, 1]
        find(".d-otp-input").fill_in(with: code)

        expect(page).to have_css(".code-login-form__signup-details-step")
        expect(captcha).to have_hcaptcha_widget
        screenshot_marker(label: "deferred-signup-captcha", only: :desktop)
      end
    end

    context "when site requires login" do
      before { SiteSetting.login_required = true }

      it "displays the captcha widget on signup page" do
        signup_page.open
        expect(captcha).to have_hcaptcha_container
      end
    end

    it "lets the user complete CAPTCHA and retry signup for approval" do
      SiteSetting.enable_local_logins_via_email = true
      SiteSetting.enable_local_logins_via_code = true
      SiteSetting.must_approve_users = true
      Jobs.run_immediately!
      stub_request(:post, "https://hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      code_signup.open.submit_email("approval@example.com")
      wait_for { ActionMailer::Base.deliveries.any? }
      code = ActionMailer::Base.deliveries.last.subject[/(\d{6})/, 1]
      code_signup.submit_code(code)

      expect(code_signup).to have_account_details
      expect(captcha).to have_hcaptcha_widget
      code_signup.fill_username("approval-user")
      screenshot_marker(label: "approval-signup-captcha", only: :desktop)

      code_signup.submit_for_approval

      expect(code_signup).to have_error(I18n.t("js.discourse_captcha.missing_token"))
      expect(code_signup).to have_username("approval-user")
      expect(page).to have_current_path("/signup")

      captcha.complete_hcaptcha
      code_signup.submit_for_approval

      expect(code_signup).to have_pending_approval
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
