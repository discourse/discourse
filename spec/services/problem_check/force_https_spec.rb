# frozen_string_literal: true

RSpec.describe ProblemCheck::ForceHttps do
  subject(:check) { described_class.new(data) }

  describe ".call" do
    before { SiteSetting.stubs(force_https: configured) }

    context "when configured to force SSL" do
      let(:configured) { true }
      let(:data) { { check_force_https: true } }

      it { expect(check.call).to be_empty }
    end

    context "when not configured to force SSL" do
      let(:configured) { false }

      context "when the request is coming over HTTPS" do
        let(:data) { { check_force_https: true } }

        it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
      end

      context "when the request is coming over HTTP" do
        let(:data) { { check_force_https: false } }

        it { expect(check.call).to be_empty }
      end
    end
  end
end
