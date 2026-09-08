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

    it "rejects invalid category IDs" do
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

      it "accepts two blank buckets" do
        change_bucket_value("")
        validate("")
      end

      it "accepts a single configured bucket" do
        change_bucket_value("")
        validate("my-awesome-bucket")
      end

      it "accepts the same bucket with different paths" do
        change_bucket_value("my-awesome-bucket/foo")
        validate("my-awesome-bucket/bar")
      end

      it "rejects identical bucket locations" do
        change_bucket_value("my-awesome-bucket")
        expect { validate("my-awesome-bucket") }.to raise_error(
          Discourse::InvalidParameters,
          error_message,
        )
      end

      it "rejects identical bucket locations with a trailing slash" do
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

      it "accepts a backup bucket below the upload bucket" do
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

      it "rejects an upload bucket below the backup bucket" do
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

  describe "#x_summary_large_image" do
    it "does not allow SVG image files" do
      upload = Fabricate(:upload, url: "/images/logo-dark.svg", extension: "svg")
      expect { validations.validate_x_summary_large_image(upload.id) }.to raise_error(
        Discourse::InvalidParameters,
        I18n.t("errors.site_settings.x_summary_large_image_no_svg"),
      )
      upload.update!(url: "/images/logo-dark.png", extension: "png")
      expect { validations.validate_x_summary_large_image(upload.id) }.not_to raise_error
      expect { validations.validate_x_summary_large_image(nil) }.not_to raise_error
    end
  end

  describe "#validate_allow_all_users_to_flag_illegal_content" do
    it "does not allow to enable when no contact email is provided" do
      expect { validations.validate_allow_all_users_to_flag_illegal_content("t") }.to raise_error(
        Discourse::InvalidParameters,
        I18n.t("errors.site_settings.tl0_and_anonymous_flag"),
      )
      SiteSetting.contact_email = "illegal@example.com"
      expect {
        validations.validate_allow_all_users_to_flag_illegal_content("t")
      }.not_to raise_error
    end
  end

  describe "#validate_allow_likes_in_anonymous_mode" do
    it "doesn't allow the setting to be enabled if the allow_anonymous_mode setting is disabled" do
      SiteSetting.allow_anonymous_mode = false

      expect { SiteSetting.allow_likes_in_anonymous_mode = true }.to raise_error(
        Discourse::InvalidParameters,
        I18n.t("errors.site_settings.allow_likes_in_anonymous_mode_without_anonymous_mode_enabled"),
      )
    end

    it "allows the setting to be enabled if the allow_anonymous_mode setting is enabled" do
      SiteSetting.allow_anonymous_mode = true

      expect { SiteSetting.allow_likes_in_anonymous_mode = true }.not_to raise_error
    end

    it "allows the setting to be disabled if the allow_anonymous_mode setting is disabled" do
      SiteSetting.allow_anonymous_mode = true
      SiteSetting.allow_likes_in_anonymous_mode = true

      SiteSetting.allow_anonymous_mode = false
      expect { SiteSetting.allow_likes_in_anonymous_mode = false }.not_to raise_error
    end
  end
end
