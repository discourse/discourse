# frozen_string_literal: true

require "site_settings/validations"

RSpec.describe SiteSettings::Validations do
  subject(:validations) { Class.new.include(described_class).new }

  describe "default_categories" do
    fab!(:category)

    it "supports valid categories" do
      expect {
        validations.validate_default_categories_watching("#{category.id}")
      }.not_to raise_error
    end

    it "won't allow you to input junk categories" do
      expect { validations.validate_default_categories_watching("junk") }.to raise_error(
        Discourse::InvalidParameters,
      )

      expect {
        validations.validate_default_categories_watching("#{category.id}|12312323")
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "prevents using the same category in more than one default group" do
      SiteSetting.default_categories_watching = "#{category.id}"

      expect { SiteSetting.default_categories_tracking = "#{category.id}" }.to raise_error(
        Discourse::InvalidParameters,
      )

      expect { SiteSetting.default_categories_normal = "#{category.id}" }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe "s3 buckets reusage" do
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
        expect { validate("my-awesome-bucket") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end

      it "should raise an error when both buckets are equal except for a trailing slash" do
        change_bucket_value("my-awesome-bucket/")
        expect { validate("my-awesome-bucket") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )

        change_bucket_value("my-awesome-bucket")
        expect { validate("my-awesome-bucket/") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end
    end

    describe "#validate_s3_backup_bucket" do
      let(:other_setting_name) { "s3_upload_bucket" }

      def validate(new_value)
        validations.validate_s3_backup_bucket(new_value)
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
        validations.validate_s3_upload_bucket(new_value)
      end

      it_behaves_like "s3 bucket validation"

      it "should raise an error when the 's3_upload_bucket' is a subdirectory of 's3_backup_bucket'" do
        SiteSetting.s3_backup_bucket = "my-awesome-bucket"
        expect { validate("my-awesome-bucket/uploads") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )

        SiteSetting.s3_backup_bucket = "my-awesome-bucket/foo"
        expect { validate("my-awesome-bucket/foo/uploads") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end

      it "cannot be made blank unless the setting is false" do
        SiteSetting.s3_backup_bucket = "really-real-cool-bucket"
        SiteSetting.enable_s3_uploads = true

        expect { validate("") }.to raise_error(Discourse::InvalidParameters)
        SiteSetting.enable_s3_uploads = false
        validate("")
      end
    end
  end

  describe "enforce second factor & local/auth provider login interplay" do
    describe "#validate_enforce_second_factor" do
      context "when local logins are disabled" do
        let(:error_message) do
          I18n.t("errors.site_settings.second_factor_cannot_be_enforced_with_disabled_local_login")
        end
        before { SiteSetting.enable_local_logins = false }

        it "should raise an error" do
          expect { validations.validate_enforce_second_factor("t") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end

        it "should be ok when the new value is 'staff'" do
          expect { validations.validate_enforce_second_factor("staff") }.not_to raise_error
        end
      end

      context "when local logins are enabled" do
        before { SiteSetting.enable_local_logins = true }

        it "should be ok" do
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
          SiteSetting.enable_discourse_connect = true
        end

        it "should raise an error" do
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

          it "should raise an error" do
            expect { validations.validate_enable_local_logins("f") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end
        end

        context "when enforce second factor is disabled" do
          before { SiteSetting.enforce_second_factor = "no" }

          it "should be ok" do
            expect { validations.validate_enable_local_logins("f") }.not_to raise_error
          end
        end

        context "when enforce second factor is staff" do
          before { SiteSetting.enforce_second_factor = "staff" }

          it "should be ok" do
            expect { validations.validate_enable_local_logins("f") }.not_to raise_error
          end
        end
      end

      context "when the new value is true" do
        it "should be ok" do
          expect { validations.validate_enable_local_logins("t") }.not_to raise_error
        end
      end
    end

    describe "#validate_cors_origins" do
      let(:error_message) do
        I18n.t("errors.site_settings.cors_origins_should_not_have_trailing_slash")
      end

      context "when the new value has trailing slash" do
        it "should raise an error" do
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

    describe "#validate_s3_use_acls" do
      context "when the new value is true" do
        it "is ok" do
          expect { validations.validate_s3_use_acls("t") }.not_to raise_error
        end
      end

      context "when the new value is false" do
        it "is ok" do
          expect { validations.validate_s3_use_acls("f") }.not_to raise_error
        end

        context "if secure uploads is enabled" do
          let(:error_message) { I18n.t("errors.site_settings.s3_use_acls_requirements") }
          before { enable_secure_uploads }

          it "is not ok" do
            expect { validations.validate_s3_use_acls("f") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end
        end
      end
    end

    describe "#validate_secure_uploads" do
      let(:error_message) { I18n.t("errors.site_settings.secure_uploads_requirements") }

      context "when the new secure uploads value is true" do
        context "if site setting for enable_s3_uploads is enabled" do
          before { SiteSetting.enable_s3_uploads = true }

          it "should be ok" do
            expect { validations.validate_secure_uploads("t") }.not_to raise_error
          end
        end

        context "if site setting for enable_s3_uploads is not enabled" do
          before { SiteSetting.enable_s3_uploads = false }

          it "is not ok" do
            expect { validations.validate_secure_uploads("t") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end

          context "if global s3 setting is enabled" do
            before { GlobalSetting.stubs(:use_s3?).returns(true) }

            it "should be ok" do
              expect { validations.validate_secure_uploads("t") }.not_to raise_error
            end
          end
        end

        context "if site setting for s3_use_acls is not enabled" do
          before { SiteSetting.s3_use_acls = false }

          it "is not ok" do
            expect { validations.validate_secure_uploads("t") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end
        end
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

          it "should be ok" do
            expect { validations.validate_enable_s3_uploads("t") }.not_to raise_error
          end
        end

        context "when the s3_upload_bucket is blank" do
          let(:error_message) { I18n.t("errors.site_settings.s3_upload_bucket_is_required") }

          before { SiteSetting.s3_upload_bucket = nil }

          it "is not ok" do
            expect { validations.validate_enable_s3_uploads("t") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end
        end

        context "when the s3_upload_bucket is not blank" do
          before { SiteSetting.s3_upload_bucket = "some-bucket" }

          it "should be ok" do
            expect { validations.validate_enable_s3_uploads("t") }.not_to raise_error
          end
        end
      end
    end
  end

  describe "slow_down_crawler_user_agents" do
    let(:too_short_message) do
      I18n.t("errors.site_settings.slow_down_crawler_user_agent_must_be_at_least_3_characters")
    end
    let(:popular_browser_message) do
      I18n.t(
        "errors.site_settings.slow_down_crawler_user_agent_cannot_be_popular_browsers",
        values:
          SiteSettings::Validations::PROHIBITED_USER_AGENT_STRINGS.join(
            I18n.t("word_connector.comma"),
          ),
      )
    end

    it "cannot contain a user agent that's shorter than 3 characters" do
      expect { validations.validate_slow_down_crawler_user_agents("ao|acsw") }.to raise_error(
        Discourse::InvalidParameters,
        too_short_message,
      )
      expect { validations.validate_slow_down_crawler_user_agents("up") }.to raise_error(
        Discourse::InvalidParameters,
        too_short_message,
      )
      expect { validations.validate_slow_down_crawler_user_agents("a|") }.to raise_error(
        Discourse::InvalidParameters,
        too_short_message,
      )
      expect { validations.validate_slow_down_crawler_user_agents("|a") }.to raise_error(
        Discourse::InvalidParameters,
        too_short_message,
      )
    end

    it "allows user agents that are 3 characters or longer" do
      expect { validations.validate_slow_down_crawler_user_agents("aoc") }.not_to raise_error
      expect { validations.validate_slow_down_crawler_user_agents("anuq") }.not_to raise_error
      expect { validations.validate_slow_down_crawler_user_agents("pupsc|kcx") }.not_to raise_error
    end

    it "allows the setting to be empty" do
      expect { validations.validate_slow_down_crawler_user_agents("") }.not_to raise_error
    end

    it "cannot contain a token of a popular browser user agent" do
      expect { validations.validate_slow_down_crawler_user_agents("mOzilla") }.to raise_error(
        Discourse::InvalidParameters,
        popular_browser_message,
      )

      expect {
        validations.validate_slow_down_crawler_user_agents("chRome|badcrawler")
      }.to raise_error(Discourse::InvalidParameters, popular_browser_message)

      expect {
        validations.validate_slow_down_crawler_user_agents("html|badcrawler")
      }.to raise_error(Discourse::InvalidParameters, popular_browser_message)
    end
  end

  describe "strip image metadata and composer media optimization interplay" do
    describe "#validate_strip_image_metadata" do
      let(:error_message) do
        I18n.t(
          "errors.site_settings.strip_image_metadata_cannot_be_disabled_if_composer_media_optimization_image_enabled",
        )
      end

      context "when the new value is false" do
        context "when composer_media_optimization_image_enabled is enabled" do
          before { SiteSetting.composer_media_optimization_image_enabled = true }

          it "should raise an error" do
            expect { validations.validate_strip_image_metadata("f") }.to raise_error(
              Discourse::InvalidParameters,
              error_message,
            )
          end
        end

        context "when composer_media_optimization_image_enabled is disabled" do
          before { SiteSetting.composer_media_optimization_image_enabled = false }

          it "should be ok" do
            expect { validations.validate_strip_image_metadata("f") }.not_to raise_error
          end
        end
      end

      context "when the new value is true" do
        it "should be ok" do
          expect { validations.validate_strip_image_metadata("t") }.not_to raise_error
        end
      end
    end
  end

  describe "#twitter_summary_large_image" do
    it "does not allow SVG image files" do
      upload = Fabricate(:upload, url: "/images/logo-dark.svg", extension: "svg")
      expect { validations.validate_twitter_summary_large_image(upload.id) }.to raise_error(
        Discourse::InvalidParameters,
        I18n.t("errors.site_settings.twitter_summary_large_image_no_svg"),
      )
      upload.update!(url: "/images/logo-dark.png", extension: "png")
      expect { validations.validate_twitter_summary_large_image(upload.id) }.not_to raise_error
      expect { validations.validate_twitter_summary_large_image(nil) }.not_to raise_error
    end
  end
end
