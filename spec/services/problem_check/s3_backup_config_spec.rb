# frozen_string_literal: true

RSpec.describe ProblemCheck::S3BackupConfig do
  subject(:check) { described_class.new }

  describe ".call" do
    let(:backup_location) { BackupLocationSiteSetting::S3 }
    let(:bucket_name) { "backups" }

    before do
      GlobalSetting.stubs(use_s3?: globally_enabled)
      SiteSetting.stubs(backup_location: backup_location)
      SiteSetting.stubs(s3_backup_bucket: bucket_name)
    end

    context "when S3 uploads are globally enabled" do
      let(:globally_enabled) { true }

      it "relies on the check in GlobalSettings#use_s3?" do
        expect(check).to be_chill_about_it
      end
    end

    context "when S3 backups are disabled" do
      let(:globally_enabled) { false }
      let(:backup_location) { nil }

      it { expect(check).to be_chill_about_it }
    end

    context "when S3 backups are enabled" do
      let(:globally_enabled) { false }

      before { SiteSetting.stubs(s3_use_iam_profile: use_iam_profile) }

      context "when configured to use IAM profile" do
        let(:use_iam_profile) { true }

        it { expect(check).to be_chill_about_it }
      end

      context "when not configured to use IAM profile" do
        let(:use_iam_profile) { false }

        before do
          SiteSetting.stubs(s3_access_key_id: access_key)
          SiteSetting.stubs(s3_secret_access_key: secret_access_key)
        end

        context "when credentials are present" do
          let(:access_key) { "foo" }
          let(:secret_access_key) { "bar" }

          it { expect(check).to be_chill_about_it }
        end

        context "when credentials are missing" do
          let(:access_key) { "foo" }
          let(:secret_access_key) { nil }

          it do
            expect(check).to have_a_problem.with_priority("low").with_message(
              'The server is configured to upload backups to S3, but at least one the following setting is not set: s3_access_key_id, s3_secret_access_key, s3_use_iam_profile, or s3_backup_bucket. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229" target="_blank">See "How to set up image uploads to S3?" to learn more</a>.',
            )
          end
        end

        context "when bucket name is missing" do
          let(:access_key) { "foo" }
          let(:secret_access_key) { "bar" }
          let(:bucket_name) { nil }

          it do
            expect(check).to have_a_problem.with_priority("low").with_message(
              'The server is configured to upload backups to S3, but at least one the following setting is not set: s3_access_key_id, s3_secret_access_key, s3_use_iam_profile, or s3_backup_bucket. Go to <a href="/admin/site_settings">the Site Settings</a> and update the settings. <a href="https://meta.discourse.org/t/how-to-set-up-image-uploads-to-s3/7229" target="_blank">See "How to set up image uploads to S3?" to learn more</a>.',
            )
          end
        end
      end
    end
  end
end
