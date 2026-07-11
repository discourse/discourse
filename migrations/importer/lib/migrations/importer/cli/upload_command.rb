# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class UploadCommand < Migrations::CLI::Command
        requires_rails!

        self.description =
          "Turn the IntermediateDB's upload_sources into uploads on the site's store, " \
            "recording the results in files.db"

        # The committed template next to the code; a gitignored `upload.local.yml`
        # beside it wins when present — the same convention the converters use for
        # their settings.
        SETTINGS_TEMPLATE_PATH = File.expand_path("../../../../config/upload.yml", __dir__)
        LOCAL_SETTINGS_PATH = File.expand_path("../../../../config/upload.local.yml", __dir__)

        options do
          option "-h/--help", "Print out help."
          option "--settings <path>",
                 "Path of the settings file. Defaults to upload.local.yml in " \
                   "migrations/importer/config if it exists, otherwise the upload.yml template there."
          option "--reset",
                 "Delete files.db before running so uploads are created from scratch. " \
                   "The download cache is kept, so URLs are not fetched again."
          option "--fix-missing",
                 "Verify each upload's file exists on the store (and its S3 ACL), repairing the record."
          option "--optimize",
                 "Precompute optimized images. Not needed when a post-import rebake will regenerate them."
        end

        def call
          return print_usage if @options[:help]

          settings = load_settings
          Database.delete_database(settings[:files_db]) if @options[:reset]
          Uploads::Uploads.perform!(settings)
        end

        private

        def load_settings
          path = @options[:settings] || default_settings_path
          raise NoSettingsFound, "Settings file not found: #{path}" unless File.exist?(path)

          # The flag and the yml key are OR-ed: passing the flag turns the mode on,
          # but a `true` in the settings file can't be turned back off from the CLI.
          settings = SettingsParser.parse!(path)
          settings[:fix_missing] = true if @options[:fix_missing]
          settings[:create_optimized_images] = true if @options[:optimize]
          settings
        end

        def default_settings_path
          File.exist?(LOCAL_SETTINGS_PATH) ? LOCAL_SETTINGS_PATH : SETTINGS_TEMPLATE_PATH
        end
      end
    end
  end
end
