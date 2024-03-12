# frozen_string_literal: true

RSpec.describe ProblemCheck::S3Cdn do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      GlobalSetting.stubs(use_s3?: globally_enabled)
      SiteSetting.stubs(enable_s3_uploads?: locally_enabled)
      SiteSetting::Upload.stubs(s3_cdn_url: cdn_url)
    end

    context "when S3 uploads are enabled" do
      let(:globally_enabled) { false }
      let(:locally_enabled) { true }

      context "when CDN URL is configured" do
        let(:cdn_url) { "https://cdn.codinghorror.com" }

        it { expect(check.call).to be_empty }
      end

      context "when CDN URL is not configured" do
        let(:cdn_url) { nil }

        it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
      end
    end

    context "when S3 uploads are disabled" do
      let(:globally_enabled) { false }
      let(:locally_enabled) { false }
      let(:cdn_url) { nil }

      it { expect(check.call).to be_empty }
    end
  end
end
