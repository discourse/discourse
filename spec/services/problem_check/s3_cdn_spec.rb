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

        it { expect(check).to be_chill_about_it }
      end

      context "when CDN URL is not configured" do
        let(:cdn_url) { nil }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            'The server is configured to upload files to S3, but there is no S3 CDN configured. This can lead to expensive S3 costs and slower site performance. <a href="https://meta.discourse.org/t/-/148916" target="_blank">See "Using Object Storage for Uploads" to learn more</a>.',
          )
        end
      end
    end

    context "when S3 uploads are disabled" do
      let(:globally_enabled) { false }
      let(:locally_enabled) { false }
      let(:cdn_url) { nil }

      it { expect(check).to be_chill_about_it }
    end
  end
end
