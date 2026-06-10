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
          "Your site has the content security policy disabled. This protection will soon become mandatory and the <a href='/admin/site_settings/category/all_results?filter=content_security_policy'>content_security_policy</a> setting will be removed. Re-enable it now and resolve any breakage it causes before the opt-out goes away.",
        )
      end
    end
  end
end
