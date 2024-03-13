# frozen_string_literal: true

RSpec.describe ProblemCheck::GoogleAnalyticsVersion do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(ga_version: version) }

    context "when using Google Analytics V3" do
      let(:version) { "v3_analytics" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your Discourse is currently using Google Analytics 3, which will no longer be supported after July 2023. <a href='https://meta.discourse.org/t/260498'>Upgrade to Google Analytics 4</a> now to continue receiving valuable insights and analytics for your website's performance.",
        )
      end
    end

    context "when using Google Analytics V4" do
      let(:version) { "v4_analytics" }

      it { expect(check).to be_chill_about_it }
    end
  end
end
