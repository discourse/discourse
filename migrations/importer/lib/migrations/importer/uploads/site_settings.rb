# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      class SiteSettings
        class S3UploadsConfigurationError < StandardError
        end

        # A migration has to accept whatever the old site accepted; a tighter
        # limit here would only manufacture skipped files. These loosenings are
        # applied unconditionally rather than being settings-file knobs.
        AUTHORIZED_EXTENSIONS = "*"
        MAX_ATTACHMENT_SIZE_KB = 102_400
        MAX_IMAGE_SIZE_KB = 102_400
        MAX_IMAGE_MEGAPIXELS = 150

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
          SiteSetting.authorized_extensions = AUTHORIZED_EXTENSIONS
          SiteSetting.max_attachment_size_kb = MAX_ATTACHMENT_SIZE_KB
          SiteSetting.max_image_size_kb = MAX_IMAGE_SIZE_KB
          SiteSetting.max_image_megapixels = MAX_IMAGE_MEGAPIXELS
          SiteSetting.secure_uploads = @options[:secure_uploads]
          SiteSetting.s3_enable_access_control_tags = @options[:s3_enable_access_control_tags]
        end

        def configure_multisite
          Rails.configuration.multisite = true

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
              UploadCreator.new(tmpfile, "discourse-s3-test.txt").create_for(
                Discourse::SYSTEM_USER_ID,
              )

            unless upload.present? && upload.persisted? && upload.errors.blank? &&
                     upload.url.start_with?("//")
              raise S3UploadsConfigurationError, "Failed to upload to S3"
            end

            upload.destroy
          end
        end
      end
    end
  end
end
