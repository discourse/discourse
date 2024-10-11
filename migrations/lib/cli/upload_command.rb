# frozen_string_literal: true

module Migrations::CLI::UploadCommand
  def self.included(thor)
    thor.class_eval do
      desc "upload", "Upload media uploads"
      option :settings,
             type: :string,
             desc: "Uploads settings file path",
             default: "./config/upload.yml",
             banner: "path"
      option :fix_missing, type: :boolean, desc: "Fix missing uploads"
      option :optimize, type: :boolean, desc: "Optimize uploads"
      def upload
        validate_options!

        ::Migrations.load_rails_environment
        require "extralite"

        puts "Starting uploads..."

        settings = ::Migrations::SettingsParser.parse!(options.settings)
        merge_settings_from_cli_args!(settings)

        ::Migrations::Uploader::Uploads.perform!(settings)
      end

      private

      def merge_settings_from_cli_args!(settings)
        settings[:fix_missing] = options.fix_missing if options.fix_missing.present?
        settings[:create_optimized_images] = options.optimize if options.optimize.present?
      end

      def validate_options!
        if !File.exist?(options.settings)
          raise ::Migrations::NoSettingsFound, "No Settings file found at #{options.settings}"
        end
      end
    end
  end
end
