# frozen_string_literal: true

require "site_settings/validations"

RSpec.describe SiteSettings::Validations do
  subject(:validations) { Class.new.include(described_class).new }

  describe "#validate_enforce_second_factor" do
    context "when local logins are disabled" do
      let(:error_message) do
        I18n.t("errors.site_settings.second_factor_cannot_be_enforced_with_disabled_local_login")
      end

      before { SiteSetting.enable_local_logins = false }

      it "raises an error" do
        expect { validations.validate_enforce_second_factor("t") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end
    end

    context "when local logins are enabled" do
      before { SiteSetting.enable_local_logins = true }

      it "is ok" do
        expect { validations.validate_enforce_second_factor("t") }.not_to raise_error
      end
    end

    context "when SSO is enabled" do
      let(:error_message) do
        I18n.t(
          "errors.site_settings.second_factor_cannot_be_enforced_with_discourse_connect_enabled",
        )
      end

      before do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.discourse_connect_secret = "x" * 10
        SiteSetting.enable_discourse_connect = true
      end

      it "raises an error" do
        expect { validations.validate_enforce_second_factor("t") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end
    end
  end

  describe "#validate_enable_local_logins" do
    let(:error_message) do
      I18n.t("errors.site_settings.local_login_cannot_be_disabled_if_second_factor_enforced")
    end

    context "when the new value is false" do
      context "when enforce second factor is enabled" do
        before { SiteSetting.enforce_second_factor = "all" }

        it "raises an error" do
          expect { validations.validate_enable_local_logins("f") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end
      end

      context "when enforce second factor is disabled" do
        before { SiteSetting.enforce_second_factor = "no" }

        it "is ok" do
          expect { validations.validate_enable_local_logins("f") }.not_to raise_error
        end
      end
    end

    context "when the new value is true" do
      it "is ok" do
        expect { validations.validate_enable_local_logins("t") }.not_to raise_error
      end
    end
  end

  describe "#validate_cors_origins" do
    let(:error_message) do
      I18n.t("errors.site_settings.cors_origins_should_not_have_trailing_slash")
    end

    context "when the new value has trailing slash" do
      it "raises an error" do
        expect { validations.validate_cors_origins("https://www.rainbows.com/") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end
    end
  end

  describe "#validate_enable_page_publishing" do
    context "when the new value is true" do
      it "is ok" do
        expect { validations.validate_enable_page_publishing("t") }.not_to raise_error
      end

      context "if secure uploads is enabled" do
        let(:error_message) { I18n.t("errors.site_settings.page_publishing_requirements") }

        before { enable_secure_uploads }

        it "is not ok" do
          expect { validations.validate_enable_page_publishing("t") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end
      end
    end
  end

  describe "#validate_secure_uploads" do
    it "allows enabling with ACLs and access control tags disabled" do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_use_acls = false
      SiteSetting.s3_enable_access_control_tags = false

      expect { validations.validate_secure_uploads("t") }.not_to raise_error
    end

    it "raises when S3 uploads are disabled" do
      SiteSetting.enable_s3_uploads = false

      expect { validations.validate_secure_uploads("t") }.to raise_error(
        Discourse::InvalidParameters,
        "S3 uploads must be enabled before enabling secure uploads.",
      )
    end

    it "allows enabling when S3 uploads are enabled globally" do
      SiteSetting.enable_s3_uploads = false
      GlobalSetting.stubs(:use_s3?).returns(true)

      expect { validations.validate_secure_uploads("t") }.not_to raise_error
    end

    it "allows disabling when S3 uploads are disabled" do
      SiteSetting.enable_s3_uploads = false

      expect { validations.validate_secure_uploads("f") }.not_to raise_error
    end
  end

  describe "#validate_enable_s3_uploads" do
    let(:error_message) do
      I18n.t("errors.site_settings.cannot_enable_s3_uploads_when_s3_enabled_globally")
    end

    context "when the new value is true" do
      context "when s3 uploads are already globally enabled" do
        before { GlobalSetting.stubs(:use_s3?).returns(true) }

        it "is not ok" do
          expect { validations.validate_enable_s3_uploads("t") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end
      end

      context "when s3 uploads are not already globally enabled" do
        before { GlobalSetting.stubs(:use_s3?).returns(false) }

        it "is ok" do
          expect { validations.validate_enable_s3_uploads("t") }.not_to raise_error
        end
      end

      context "when the s3_upload_bucket is blank" do
        let(:error_message) { I18n.t("errors.site_settings.s3_upload_bucket_is_required") }

        before { SiteSetting.s3_upload_bucket = "" }

        it "is not ok" do
          expect { validations.validate_enable_s3_uploads("t") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end
      end

      context "when the s3_upload_bucket is not blank" do
        before { SiteSetting.s3_upload_bucket = "some-bucket" }

        it "is ok" do
          expect { validations.validate_enable_s3_uploads("t") }.not_to raise_error
        end
      end
    end
  end
end
