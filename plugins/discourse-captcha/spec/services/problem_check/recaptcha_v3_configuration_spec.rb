# frozen_string_literal: true

RSpec.describe ProblemCheck::RecaptchaV3Configuration do
  subject(:check) { described_class.new }

  shared_examples "fails_problem_check" do
    it do
      expect(check).to have_a_problem.with_priority("high").with_message(
        "There is a problem with your ReCaptcha v3 `site_key` or `secret_key` configuration",
      )
    end
  end

  shared_examples "passes_problem_check" do
    it { expect(check).to be_chill_about_it }
  end

  context "when discourse_captcha_provider siteSetting is ReCaptcha v3" do
    before do
      SiteSetting.discourse_captcha_enabled = true
      SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V3
    end

    describe "`recaptcha_v3_site_key` is not set" do
      before { SiteSetting.recaptcha_v3_secret_key = "just a string" }

      include_examples "fails_problem_check"
    end

    describe "`recaptcha_v3_secret_key` is not set" do
      before { SiteSetting.recaptcha_v3_site_key = "just a string" }

      include_examples "fails_problem_check"
    end

    describe "`recaptcha_v3_secret_key` and `recaptcha_v3_site_key` are not set" do
      include_examples "fails_problem_check"
    end

    describe "`recaptcha_v3_secret_key` and `recaptcha_v3_site_key` are set" do
      before do
        SiteSetting.recaptcha_v3_secret_key = "just a string"
        SiteSetting.recaptcha_v3_site_key = "just a string"
      end

      include_examples "passes_problem_check"
    end
  end

  context "when discourse_captcha_provider siteSetting is none" do
    before { SiteSetting.discourse_captcha_provider = DiscourseCaptcha::CaptchaProvider::NONE }

    describe "`recaptcha_v3_site_key` is not set" do
      before { SiteSetting.recaptcha_v3_secret_key = "just a string" }

      include_examples "passes_problem_check"
    end

    describe "`recaptcha_v3_secret_key` is not set" do
      before { SiteSetting.recaptcha_v3_site_key = "just a string" }

      include_examples "passes_problem_check"
    end

    describe "`recaptcha_v3_secret_key` and `recaptcha_v3_site_key` are set" do
      before do
        SiteSetting.recaptcha_v3_secret_key = "just a string"
        SiteSetting.recaptcha_v3_site_key = "just a string"
      end

      include_examples "passes_problem_check"
    end
  end
end
