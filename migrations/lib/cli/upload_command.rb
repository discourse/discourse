# frozen_string_literal: true

module Migrations::CLI
  class UploadCommand
    def initialize(options)
      @options = options
    end

    def execute
      puts "Starting uploads..."

      validate_settings_file!
      settings = load_settings

      ::Migrations::Uploader::Uploads.perform!(settings)

      puts ""
    end

    private

    def load_settings
      settings = ::Migrations::SettingsParser.parse!(@options.settings)
      merge_settings_from_cli_args!(@options, settings)

      settings
    end

    def merge_settings_from_cli_args!(settings)
      settings[:fix_missing] = options.fix_missing if @options.fix_missing.present?
      settings[:create_optimized_images] = options.optimize if @options.optimize.present?
    end

    def validate_settings_file!
      path = @options.settings

      raise ::Migrations::NoSettingsFound, "Settings file not found: #{path}" if !File.exist?(path)
    end
  end
end
