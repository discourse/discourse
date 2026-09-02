# frozen_string_literal: true

RSpec.describe ProblemCheck::FacebookConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_facebook_logins: enabled) }

    context "when Facebook authentication is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when Facebook authentication is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: "foo")
        SiteSetting.stubs(facebook_app_secret: "bar")
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when Facebook authentication is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: nil)
        SiteSetting.stubs(facebook_app_secret: "bar")
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_facebook_logins}} is on, but {{setting:facebook_app_id}} must still be set. <a href="https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394" target="_blank">See this guide to learn more</a>.',
        )
      end
    end

    context "when Facebook authentication is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: "foo")
        SiteSetting.stubs(facebook_app_secret: nil)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_facebook_logins}} is on, but {{setting:facebook_app_secret}} must still be set. <a href="https://meta.discourse.org/t/configuring-facebook-login-for-discourse/13394" target="_blank">See this guide to learn more</a>.',
        )
      end
    end
  end
end
