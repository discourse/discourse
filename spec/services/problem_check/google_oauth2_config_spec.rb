# frozen_string_literal: true

RSpec.describe ProblemCheck::GoogleOauth2Config do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_google_oauth2_logins: enabled) }

    context "when Google OAuth is disabled" do
      let(:enabled) { false }

      it { expect(check.call).to be_empty }
    end

    context "when Google OAuth is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: "foo")
        SiteSetting.stubs(google_oauth2_client_secret: "bar")
      end

      it { expect(check.call).to be_empty }
    end

    context "when Google OAuth is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: nil)
        SiteSetting.stubs(google_oauth2_client_secret: "bar")
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when Google OAuth is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(google_oauth2_client_id: "foo")
        SiteSetting.stubs(google_oauth2_client_secret: nil)
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end
