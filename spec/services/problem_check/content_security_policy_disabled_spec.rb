# frozen_string_literal: true

RSpec.describe ProblemCheck::ContentSecurityPolicyDisabled do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(content_security_policy: configured) }

    context "when the content security policy is enabled" do
      let(:configured) { true }

      it { expect(check).to be_chill_about_it }
    end

    context "when the content security policy is disabled" do
      let(:configured) { false }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          I18n.t("dashboard.problem.content_security_policy_disabled", base_path: ""),
        )
      end
    end
  end
end
