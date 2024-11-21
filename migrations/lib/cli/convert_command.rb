# frozen_string_literal: true

module Migrations::CLI
  class ConvertCommand
    def initialize(converter_type, options)
      @converter_type = converter_type.downcase
      @options = options
    end

    def execute
      validate_converter_type!
      settings = load_settings

      ::Migrations::Database.reset!(settings[:intermediate_db][:path]) if @options[:reset]

      converter = "migrations/converters/#{@converter_type}/converter".camelize.constantize
      converter.new(settings).run
    end

    private

    def validate_converter_type!
      converter_names = ::Migrations::Converters.names

      raise Thor::Error, <<~MSG if !converter_names.include?(@converter_type)
        Unknown converter name: #{@converter_type}
        Valid names are: #{converter_names.join(", ")}
      MSG
    end

    def validate_settings_path!(settings_path)
      raise Thor::Error, "Settings file not found: #{settings_path}" if !File.exist?(settings_path)
    end

    def load_settings
      settings_path = calculate_settings_path
      validate_settings_path!(settings_path)

      YAML.safe_load(File.read(settings_path), symbolize_names: true)
    end

    def calculate_settings_path
      settings_path =
        @options[:settings] || ::Migrations::Converters.default_settings_path(@converter_type)
      File.expand_path(settings_path, Dir.pwd)
    end
  end
end
