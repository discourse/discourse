# frozen_string_literal: true

require 'rails_helper'
require 'site_settings/validations'

describe SiteSettings::Validations do
  subject { Class.new.include(described_class).new }

  context "default_categories" do
    fab!(:category) { Fabricate(:category) }

    it "supports valid categories" do
      expect { subject.validate_default_categories_watching("#{category.id}") }.not_to raise_error
    end

    it "won't allow you to input junk categories" do
      expect {
        subject.validate_default_categories_watching("junk")
      }.to raise_error(Discourse::InvalidParameters)

      expect {
        subject.validate_default_categories_watching("#{category.id}|12312323")
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "prevents using the same category in more than one default group" do
      SiteSetting.default_categories_watching = "#{category.id}"

      expect {
        SiteSetting.default_categories_tracking = "#{category.id}"
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  context "s3 buckets reusage" do
    let(:error_message) { I18n.t("errors.site_settings.s3_bucket_reused") }

    shared_examples "s3 bucket validation" do
      def change_bucket_value(value)
        SiteSetting.set(other_setting_name, value)
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

  describe "enforce second factor & local login interplay" do
    describe "#validate_enforce_second_factor" do
      let(:error_message) { I18n.t("errors.site_settings.second_factor_cannot_be_enforced_with_disabled_local_login") }
      context "when local logins are disabled" do
        before do
          SiteSetting.enable_local_logins = false
        end

        it "should raise an error" do
          expect { subject.validate_enforce_second_factor("t") }.to raise_error(Discourse::InvalidParameters, error_message)
        end
      end

      context "when local logins are enabled" do
        before do
          SiteSetting.enable_local_logins = true
        end

        it "should be ok" do
          expect { subject.validate_enforce_second_factor("t") }.not_to raise_error
        end
      end
    end

    describe "#validate_enable_local_logins" do
      let(:error_message) { I18n.t("errors.site_settings.local_login_cannot_be_disabled_if_second_factor_enforced") }

      context "when the new value is false" do
        context "when enforce second factor is enabled" do
          before do
            SiteSetting.enforce_second_factor = "all"
          end

          it "should raise an error" do
            expect { subject.validate_enable_local_logins("f") }.to raise_error(Discourse::InvalidParameters, error_message)
          end
        end

        context "when enforce second factor is disabled" do
          before do
            SiteSetting.enforce_second_factor = "no"
          end

          it "should be ok" do
            expect { subject.validate_enable_local_logins("f") }.not_to raise_error
          end
        end
      end

      context "when the new value is true" do
        it "should be ok" do
          expect { subject.validate_enable_local_logins("t") }.not_to raise_error
        end
      end
    end

    describe "#validate_secure_media" do
      let(:error_message) { I18n.t("errors.site_settings.secure_media_requirements") }

      context "when the new value is true" do
        context 'if site setting for enable_s3_uploads is enabled' do
          before do
            SiteSetting.enable_s3_uploads = true
          end

          it "should be ok" do
            expect { subject.validate_secure_media("t") }.not_to raise_error
          end
        end

        context 'if site setting for enable_s3_uploads is not enabled' do
          before do
            SiteSetting.enable_s3_uploads = false
          end

          it "is not ok" do
            expect { subject.validate_secure_media("t") }.to raise_error(Discourse::InvalidParameters, error_message)
          end

          context "if global s3 setting is enabled" do
            before do
              GlobalSetting.stubs(:use_s3?).returns(true)
            end

            it "should be ok" do
              expect { subject.validate_secure_media("t") }.not_to raise_error
            end
          end
        end
      end
    end

    describe "#validate_enable_s3_uploads" do
      let(:error_message) { I18n.t("errors.site_settings.cannot_enable_s3_uploads_when_s3_enabled_globally") }

      context "when the new value is true" do
        context "when s3 uploads are already globally enabled" do
          before do
            GlobalSetting.stubs(:use_s3?).returns(true)
          end

          it "is not ok" do
            expect { subject.validate_enable_s3_uploads("t") }.to raise_error(Discourse::InvalidParameters, error_message)
          end
        end

        context "when s3 uploads are not already globally enabled" do
          before do
            GlobalSetting.stubs(:use_s3?).returns(false)
          end

          it "should be ok" do
            expect { subject.validate_enable_s3_uploads("t") }.not_to raise_error
          end
        end

        context "when the s3_upload_bucket is blank" do
          let(:error_message) { I18n.t("errors.site_settings.s3_upload_bucket_is_required") }

          before do
            SiteSetting.s3_upload_bucket = nil
          end

          it "is not ok" do
            expect { subject.validate_enable_s3_uploads("t") }.to raise_error(Discourse::InvalidParameters, error_message)
          end
        end

        context "when the s3_upload_bucket is not blank" do
          before do
            SiteSetting.s3_upload_bucket = "some-bucket"
          end

          it "should be ok" do
            expect { subject.validate_enable_s3_uploads("t") }.not_to raise_error
          end
        end
      end
    end
  end
end
