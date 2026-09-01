# frozen_string_literal: true

RSpec.describe ProblemCheck::S3UploadConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      GlobalSetting.stubs(use_s3?: globally_enabled)
      SiteSetting.stubs(enable_s3_uploads?: locally_enabled)
    end

    context "when S3 uploads are globally enabled" do
      let(:globally_enabled) { true }
      let(:locally_enabled) { false }

      it "relies on the check in GlobalSettings#use_s3?" do
        expect(check).to be_chill_about_it
      end
    end

    context "when S3 uploads are disabled" do
      let(:globally_enabled) { false }
      let(:locally_enabled) { false }

      it { expect(check).to be_chill_about_it }
    end

    context "when S3 uploads are locally enabled" do
      let(:globally_enabled) { false }
      let(:locally_enabled) { true }

      before { SiteSetting.stubs(s3_use_iam_profile: use_iam_profile) }

      context "when configured to use IAM profile" do
        let(:use_iam_profile) { true }

        it { expect(check).to be_chill_about_it }
      end

      context "when not configured to use IAM profile" do
        let(:use_iam_profile) { false }

        it "accepts complete credentials and a bucket name" do
          SiteSetting.stubs(s3_access_key_id: "foo")
          SiteSetting.stubs(s3_secret_access_key: "bar")
          SiteSetting.stubs(s3_upload_bucket: "baz")

          expect(check).to be_chill_about_it
        end

        it "reports the missing S3 credentials" do
          SiteSetting.stubs(s3_access_key_id: "foo")
          SiteSetting.stubs(s3_secret_access_key: nil)
          SiteSetting.stubs(s3_upload_bucket: "baz")

          expect(check).to have_a_problem.with_priority("low").with_message(
            'The server is configured to upload files to S3, but at least one the following setting is not set: s3_access_key_id, s3_secret_access_key, s3_use_iam_profile, or s3_upload_bucket. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229" target="_blank">See "How to set up image uploads to S3?" to learn more</a>.',
          )
        end

        it "reports the missing S3 bucket name" do
          SiteSetting.stubs(s3_access_key_id: "foo")
          SiteSetting.stubs(s3_secret_access_key: "bar")
          SiteSetting.stubs(s3_upload_bucket: nil)

          expect(check).to have_a_problem.with_priority("low").with_message(
            'The server is configured to upload files to S3, but at least one the following setting is not set: s3_access_key_id, s3_secret_access_key, s3_use_iam_profile, or s3_upload_bucket. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229" target="_blank">See "How to set up image uploads to S3?" to learn more</a>.',
          )
        end
      end
    end
  end
end
