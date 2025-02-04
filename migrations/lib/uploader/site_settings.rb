# frozen_string_literal: true

module Migrations::Uploader
  class SiteSettings
    class S3UploadsConfigurationError < StandardError
    end

    def initialize(options)
      @options = options
    end

    def configure!
      configure_basic_uploads
      configure_multisite if @options[:multisite]
      configure_s3 if @options[:enable_s3_uploads]
    end

    def self.configure!(options)
      new(options).configure!
    end

    private

    def configure_basic_uploads
      SiteSetting.clean_up_uploads = false
      SiteSetting.authorized_extensions = @options[:authorized_extensions]
      SiteSetting.max_attachment_size_kb = @options[:max_attachment_size_kb]
      SiteSetting.max_image_size_kb = @options[:max_image_size_kb]
    end

    def configure_multisite
      # rubocop:disable Discourse/NoDirectMultisiteManipulation
      Rails.configuration.multisite = true
      # rubocop:enable Discourse/NoDirectMultisiteManipulation

      RailsMultisite::ConnectionManagement.class_eval do
        def self.current_db_override=(value)
          @current_db_override = value
        end
        def self.current_db
          @current_db_override
        end
      end

      RailsMultisite::ConnectionManagement.current_db_override = @options[:multisite_db_name]
    end

    def configure_s3
      SiteSetting.s3_access_key_id = @options[:s3_access_key_id]
      SiteSetting.s3_secret_access_key = @options[:s3_secret_access_key]
      SiteSetting.s3_upload_bucket = @options[:s3_upload_bucket]
      SiteSetting.s3_region = @options[:s3_region]
      SiteSetting.s3_cdn_url = @options[:s3_cdn_url]
      SiteSetting.enable_s3_uploads = true

      if SiteSetting.enable_s3_uploads != true
        raise S3UploadsConfigurationError, "Failed to enable S3 uploads"
      end

      verify_s3_uploads_configuration!
    end

    def verify_s3_uploads_configuration!
      Tempfile.open("discourse-s3-test") do |tmpfile|
        tmpfile.write("test")
        tmpfile.rewind

        upload =
          UploadCreator.new(tmpfile, "discourse-s3-test.txt").create_for(Discourse::SYSTEM_USER_ID)

        unless upload.present? && upload.persisted? && upload.errors.blank? &&
                 upload.url.start_with?("//")
          raise S3UploadsConfigurationError, "Failed to upload to S3"
        end

        upload.destroy
      end
    end
  end
end
