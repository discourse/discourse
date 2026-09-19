# frozen_string_literal: true

RSpec.describe ProblemCheck::GithubConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_github_logins: enabled) }

    context "when GitHub authentication is disabled" do
      let(:enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when GitHub authentication is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(github_client_id: "foo")
        SiteSetting.stubs(github_client_secret: "bar")
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when GitHub authentication is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(github_client_id: nil)
        SiteSetting.stubs(github_client_secret: "bar")
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_github_logins}} is on, but {{setting:github_client_id}} must still be set. <a href="https://meta.discourse.org/t/configuring-github-login-for-discourse/13745" target="_blank">See this guide to learn more</a>.',
        )
      end
    end

    context "when GitHub authentication is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(github_client_id: "foo")
        SiteSetting.stubs(github_client_secret: nil)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          '{{setting:enable_github_logins}} is on, but {{setting:github_client_secret}} must still be set. <a href="https://meta.discourse.org/t/configuring-github-login-for-discourse/13745" target="_blank">See this guide to learn more</a>.',
        )
      end
    end
  end
end
