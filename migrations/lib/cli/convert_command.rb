# frozen_string_literal: true

module Migrations::CLI::ConvertCommand
  def self.included(thor)
    thor.class_eval do
      desc "convert [FROM]", "Convert a file"
      option :settings, type: :string, desc: "Path of settings file", banner: "path"
      option :reset, type: :boolean, desc: "Reset database before converting data"
      def convert(converter_type)
        converter_type = converter_type.downcase
        validate_converter_type!(converter_type)

        settings_path = calculate_settings_path(converter_type)
        validate_settings_path!(settings_path)

        Migrations.load_rails_environment

        puts "Converting..."

        Migrations::IntermediateDB::Migrator.reset!("/tmp/converter/intermediate.db")
        Migrations::IntermediateDB::Migrator.migrate("/tmp/converter/intermediate.db")
      end

      private

      def validate_converter_type!(type)
        converter_names = Migrations::Converters.names

        raise Thor::Error, <<~MSG if !converter_names.include?(type)
            Unknown converter name: #{type}
            Valid names are: #{converter_names.join(", ")}
          MSG
      end

      def validate_settings_path!(settings_path)
        if !File.exist?(settings_path)
          raise Thor::Error, "Settings file not found: #{settings_path}"
        end
      end

      def validate_options(options)
        if File.exist?(OutputDatabase::DEFAULT_PATH)
          options.compatible = compatible_database?(options.from) if options.compatible.nil?
          if !options.reset && !options.compatible
            prompt.error("Incompatible database found")
            exit(1)
          end
        end
      end

      def compatible_database?(type)
        Migrations::IntermediateDB::Connection.connect(path) do |db|
          db.get_config_value(CONFIG_CONVERTING_FROM) == type
        end
      rescue Extralite::SQLError
        false
      end

      def calculate_settings_path(converter_type)
        settings_path =
          options[:settings] || Migrations::Converters.default_settings_path(converter_type)
        File.expand_path(settings_path, Dir.pwd)
      end
    end
  end
end
