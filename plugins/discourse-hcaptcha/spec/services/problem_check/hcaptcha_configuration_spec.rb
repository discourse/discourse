# frozen_string_literal: true

RSpec.describe ProblemCheck::HcaptchaConfiguration do
  subject(:check) { described_class.new }

  shared_examples "fails_problem_check" do
    it do
      expect(check).to have_a_problem.with_priority("high").with_message(
        "There is a problem with your hCaptcha `site_key` or `secret_key` configuration",
      )
    end
  end

  shared_examples "passes_problem_check" do
    it { expect(check).to be_chill_about_it }
  end

  context "when discourse_hcaptcha_enabled siteSetting is true" do
    before { SiteSetting.discourse_hcaptcha_enabled = true }

    describe "`hcaptcha_site_key` is not set" do
      before { SiteSetting.hcaptcha_secret_key = "just a string" }

      include_examples "fails_problem_check"
    end

    describe "`hcaptcha_secret_key` is not set" do
      before { SiteSetting.hcaptcha_site_key = "just a string" }

      include_examples "fails_problem_check"
    end

    describe "`hcaptcha_secret_key` and `hcaptcha_site_key` are not set" do
      include_examples "fails_problem_check"
    end

    describe "`hcaptcha_secret_key` and `hcaptcha_site_key` are set" do
      before do
        SiteSetting.hcaptcha_secret_key = "just a string"
        SiteSetting.hcaptcha_site_key = "just a string"
      end
      include_examples "passes_problem_check"
    end
  end

  context "when discourse_hcaptcha_enabled siteSetting is false" do
    before { SiteSetting.discourse_hcaptcha_enabled = false }

    describe "`hcaptcha_site_key` is not set" do
      before { SiteSetting.hcaptcha_secret_key = "just a string" }

      include_examples "passes_problem_check"
    end

    describe "`hcaptcha_secret_key` is not set" do
      before { SiteSetting.hcaptcha_site_key = "just a string" }

      include_examples "passes_problem_check"
    end

    describe "`hcaptcha_secret_key` and `hcaptcha_site_key` are not set" do
      include_examples "passes_problem_check"
    end

    describe "`hcaptcha_secret_key` and `hcaptcha_site_key` are set" do
      before do
        SiteSetting.hcaptcha_secret_key = "just a string"
        SiteSetting.hcaptcha_site_key = "just a string"
      end
      include_examples "passes_problem_check"
    end
  end
end
