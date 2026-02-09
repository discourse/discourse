# frozen_string_literal: true

require "s3_cors_rulesets"

RSpec.describe S3CorsRulesets do
  describe "#sync" do
    let(:use_db_s3_config) { false }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }

    it "does nothing when S3 is not set up" do
      client.expects(:get_bucket_cors).never
      sync_rules
    end

    context "when S3 is set up with global settings" do
      let(:use_db_s3_config) { false }
      before do
        global_setting :s3_bucket, "s3-upload-bucket"
        global_setting :s3_backup_bucket, "s3-backup-upload-bucket"
        global_setting :s3_region, "us-west-2"
      end

      it "does nothing if !s3_install_cors_rule" do
        SiteSetting.s3_install_cors_rule = false
        client.expects(:get_bucket_cors).never
        result = sync_rules
        expect(result).to eq(nil)
      end

      it "only tries to apply the ASSETS rules by default" do
        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end

      it "does not apply the ASSETS rules if they already exist" do
        client.stub_responses(:get_bucket_cors, { cors_rules: [S3CorsRulesets::ASSETS] })
        client.expects(:put_bucket_cors).never
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_EXISTED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end

      it "applies the ASSETS rules and the BACKUP_DIRECT_UPLOAD rules if S3 backups are enabled" do
        setup_backups

        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        client.expects(:put_bucket_cors).with(
          bucket: "s3-backup-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::BACKUP_DIRECT_UPLOAD],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
      end

      it "applies the ASSETS rules and the DIRECT_UPLOAD rules when S3 direct uploads are enabled" do
        SiteSetting.enable_direct_s3_uploads = true

        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::DIRECT_UPLOAD],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end

      it "does no changes if all the rules already exist" do
        SiteSetting.enable_direct_s3_uploads = true
        setup_backups

        client.stub_responses(
          :get_bucket_cors,
          {
            cors_rules: [
              S3CorsRulesets::ASSETS,
              S3CorsRulesets::BACKUP_DIRECT_UPLOAD,
              S3CorsRulesets::DIRECT_UPLOAD,
            ],
          },
        )
        client.expects(:put_bucket_cors).never
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_EXISTED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_EXISTED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_EXISTED)
      end

      def setup_backups
        SiteSetting.enable_backups = true
        SiteSetting.s3_backup_bucket = "s3-backup-upload-bucket"
        SiteSetting.backup_location = BackupLocationSiteSetting::S3
      end
    end

    context "when S3 is set up with database settings" do
      let(:use_db_s3_config) { true }

      before { setup_s3 }

      it "only tries to apply the ASSETS rules by default" do
        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end

      it "does not apply the ASSETS rules if they already exist" do
        client.stub_responses(:get_bucket_cors, { cors_rules: [S3CorsRulesets::ASSETS] })
        client.expects(:put_bucket_cors).never
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_EXISTED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end

      it "applies the ASSETS rules and the BACKUP_DIRECT_UPLOAD rules if S3 backups are enabled" do
        SiteSetting.enable_backups = true
        SiteSetting.s3_backup_bucket = "s3-backup-upload-bucket"
        SiteSetting.backup_location = BackupLocationSiteSetting::S3

        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        client.expects(:put_bucket_cors).with(
          bucket: "s3-backup-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::BACKUP_DIRECT_UPLOAD],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
      end

      it "applies the ASSETS rules and the DIRECT_UPLOAD rules when S3 direct uploads are enabled" do
        SiteSetting.enable_direct_s3_uploads = true

        client.stub_responses(:get_bucket_cors, {})
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::ASSETS],
          },
        )
        client.expects(:put_bucket_cors).with(
          bucket: "s3-upload-bucket",
          cors_configuration: {
            cors_rules: [S3CorsRulesets::DIRECT_UPLOAD],
          },
        )
        result = sync_rules
        expect(result[:assets_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:direct_upload_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_APPLIED)
        expect(result[:backup_rules_status]).to eq(S3CorsRulesets::RULE_STATUS_SKIPPED)
      end
    end
  end

  def sync_rules
    described_class.sync(use_db_s3_config: use_db_s3_config, s3_client: client)
  end
end
