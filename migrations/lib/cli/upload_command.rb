# frozen_string_literal: true

module Migrations::CLI::UploadCommand
  def self.included(thor)
    thor.class_eval do
      desc "upload", "Upload media uploads"
      option :settings,
             type: :string,
             desc: "Uploads settings file path",
             default: "./migrations/config/upload.yml",
             aliases: "-s",
             banner: "path"
      option :fix_missing, type: :boolean, desc: "Fix missing uploads"
      option :optimize, type: :boolean, desc: "Optimize uploads"
      def upload
        puts "Starting uploads..."

        validate_settings_file!
        settings = load_settings

        ::Migrations::Uploader::Uploads.perform!(settings)

        puts ""
      end

      private

      def load_settings
        settings = ::Migrations::SettingsParser.parse!(options.settings)
        merge_settings_from_cli_args!(settings)

        settings
      end

      def merge_settings_from_cli_args!(settings)
        settings[:fix_missing] = options.fix_missing if options.fix_missing.present?
        settings[:create_optimized_images] = options.optimize if options.optimize.present?
      end

      def validate_settings_file!
        path = options.settings

        if !File.exist?(path)
          raise ::Migrations::NoSettingsFound, "Settings file not found: #{path}"
        end
      end
    end
  end
end
