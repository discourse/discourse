require 'rails_helper'
require 'site_settings/validations'

describe SiteSettings::Validations do
  subject { Class.new.include(described_class).new }

  context "s3 buckets reusage" do
    let(:error_message) { I18n.t("errors.site_settings.s3_bucket_reused") }

    shared_examples "s3 bucket validation" do
      def change_bucket_value(value)
        SiteSetting.public_send("#{other_setting_name}=", value)
      end

      it "shouldn't raise an error when both buckets are blank" do
        change_bucket_value("")
        validate("")
      end

      it "shouldn't raise an error when only one bucket is set" do
        change_bucket_value("")
        validate("my-awesome-bucket")
      end

      it "shouldn't raise an error when both buckets are equal, but use a different path" do
        change_bucket_value("my-awesome-bucket/foo")
        validate("my-awesome-bucket/bar")
      end

      it "should raise an error when both buckets are equal" do
        change_bucket_value("my-awesome-bucket")
        expect { validate("my-awesome-bucket") }.to raise_error(Discourse::InvalidParameters, error_message)
      end

      it "should raise an error when both buckets are equal except for a trailing slash" do
        change_bucket_value("my-awesome-bucket/")
        expect { validate("my-awesome-bucket") }.to raise_error(Discourse::InvalidParameters, error_message)

        change_bucket_value("my-awesome-bucket")
        expect { validate("my-awesome-bucket/") }.to raise_error(Discourse::InvalidParameters, error_message)
      end
    end

    describe "#validate_s3_backup_bucket" do
      let(:other_setting_name) { "s3_upload_bucket" }

      def validate(new_value)
        subject.validate_s3_backup_bucket(new_value)
      end

      it_behaves_like "s3 bucket validation"

      it "shouldn't raise an error when the 's3_backup_bucket' is a subdirectory of 's3_upload_bucket'" do
        SiteSetting.s3_upload_bucket = "my-awesome-bucket"
        validate("my-awesome-bucket/backups")

        SiteSetting.s3_upload_bucket = "my-awesome-bucket/foo"
        validate("my-awesome-bucket/foo/backups")
      end
    end

    describe "#validate_s3_upload_bucket" do
      let(:other_setting_name) { "s3_backup_bucket" }

      def validate(new_value)
        subject.validate_s3_upload_bucket(new_value)
      end

      it_behaves_like "s3 bucket validation"

      it "should raise an error when the 's3_upload_bucket' is a subdirectory of 's3_backup_bucket'" do
        SiteSetting.s3_backup_bucket = "my-awesome-bucket"
        expect { validate("my-awesome-bucket/uploads") }.to raise_error(Discourse::InvalidParameters, error_message)

        SiteSetting.s3_backup_bucket = "my-awesome-bucket/foo"
        expect { validate("my-awesome-bucket/foo/uploads") }.to raise_error(Discourse::InvalidParameters, error_message)
      end
    end
  end
end
