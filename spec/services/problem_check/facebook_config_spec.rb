# frozen_string_literal: true

RSpec.describe ProblemCheck::FacebookConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(enable_facebook_logins: enabled) }

    context "when Facebook authentication is disabled" do
      let(:enabled) { false }

      it { expect(check.call).to be_empty }
    end

    context "when Facebook authentication is enabled and configured" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: "foo")
        SiteSetting.stubs(facebook_app_secret: "bar")
      end

      it { expect(check.call).to be_empty }
    end

    context "when Facebook authentication is enabled but missing client ID" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: nil)
        SiteSetting.stubs(facebook_app_secret: "bar")
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when Facebook authentication is enabled but missing client secret" do
      let(:enabled) { true }

      before do
        SiteSetting.stubs(facebook_app_id: "foo")
        SiteSetting.stubs(facebook_app_secret: nil)
      end

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end
