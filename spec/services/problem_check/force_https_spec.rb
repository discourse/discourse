# frozen_string_literal: true

RSpec.describe ProblemCheck::ForceHttps do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(force_https: configured) }

    context "when configured to force SSL" do
      let(:configured) { true }

      it { expect(check).to be_chill_about_it }
    end

    context "when not configured to force SSL" do
      let(:configured) { false }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your website is using SSL. But `<a href='/admin/site_settings/category/all_results?filter=force_https'>force_https</a>` is not yet enabled in your site settings.",
        )
      end
    end
  end
end
