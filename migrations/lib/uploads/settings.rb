# frozen_string_literal: true

require "sqlite3"

module Migrations
  module Uploads
    class Settings
      attr_reader :config, :output_db

      def initialize(options)
        options[:path_replacements] ||= []

        @root_paths = options[:root_paths]
        @output_db = create_connection(options[:output_db_path])
        @options = options

        initialize_output_db
        configure_site_settings
      end

      def self.from_file(path)
        new(YAML.load_file(path, symbolize_names: true))
      end

      # TODO: compare against dynamically defining getter methods for
      # each top-level setting
      def [](key)
        @options[key]
      end

      private

      # TODO: Use IntermediateDatabase instead
      def create_connection(path)
        sqlite = SQLite3::Database.new(path, results_as_hash: true)
        sqlite.busy_timeout = 60_000 # 60 seconds
        sqlite.journal_mode = "WAL"
        sqlite.synchronous = "off"
        sqlite
      end

      def initialize_output_db
        @statement_counter = 0

        @output_db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS uploads (
            id TEXT PRIMARY KEY NOT NULL,
            upload JSON_TEXT,
            markdown TEXT,
            skip_reason TEXT
          )
        SQL

        @output_db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS optimized_images (
            id TEXT PRIMARY KEY NOT NULL,
            optimized_images JSON_TEXT
          )
        SQL
      end

      def configure_site_settings
        settings = @options[:site_settings]

        SiteSetting.clean_up_uploads = false
        SiteSetting.authorized_extensions = settings[:authorized_extensions]
        SiteSetting.max_attachment_size_kb = settings[:max_attachment_size_kb]
        SiteSetting.max_image_size_kb = settings[:max_image_size_kb]

        if settings[:multisite]
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
          RailsMultisite::ConnectionManagement.current_db_override = settings[:multisite_db_name]
        end

        if settings[:enable_s3_uploads]
          SiteSetting.s3_access_key_id = settings[:s3_access_key_id]
          SiteSetting.s3_secret_access_key = settings[:s3_secret_access_key]
          SiteSetting.s3_upload_bucket = settings[:s3_upload_bucket]
          SiteSetting.s3_region = settings[:s3_region]
          SiteSetting.s3_cdn_url = settings[:s3_cdn_url]
          SiteSetting.enable_s3_uploads = true

          raise "Failed to enable S3 uploads" if SiteSetting.enable_s3_uploads != true

          Tempfile.open("discourse-s3-test") do |tmpfile|
            tmpfile.write("test")
            tmpfile.rewind

            upload =
              UploadCreator.new(tmpfile, "discourse-s3-test.txt").create_for(
                Discourse::SYSTEM_USER_ID,
              )

            unless upload.present? && upload.persisted? && upload.errors.blank? &&
                     upload.url.start_with?("//")
              raise "Failed to upload to S3"
            end

            upload.destroy
          end
        end
      end
    end
  end
end
