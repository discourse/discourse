# frozen_string_literal: true

RSpec.describe ProblemCheck::GoogleAnalyticsVersion do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(ga_version: version) }

    context "when using Google Analytics V3" do
      let(:version) { "v3_analytics" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when using Google Analytics V4" do
      let(:version) { "v4_analytics" }

      it { expect(check.call).to be_empty }
    end
  end
end
