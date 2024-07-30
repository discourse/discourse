# frozen_string_literal: true

RSpec.describe ProblemCheck::ForceHttps do
  subject(:check) { described_class.new(data) }

  describe ".call" do
    before { SiteSetting.stubs(force_https: configured) }

    context "when configured to force SSL" do
      let(:configured) { true }
      let(:data) { { check_force_https: true } }

      it { expect(check).to be_chill_about_it }
    end

    context "when not configured to force SSL" do
      let(:configured) { false }

      context "when the request is coming over HTTPS" do
        let(:data) { { check_force_https: true } }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            "Your website is using SSL. But `<a href='/admin/site_settings/category/all_results?filter=force_https'>force_https</a>` is not yet enabled in your site settings.",
          )
        end
      end

      context "when the request is coming over HTTP" do
        let(:data) { { check_force_https: false } }

        it { expect(check).to be_chill_about_it }
      end
    end
  end
end
