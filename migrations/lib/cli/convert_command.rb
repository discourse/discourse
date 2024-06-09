# frozen_string_literal: true

module Migrations::CLI::ConvertCommand
  def self.included(thor)
    thor.class_eval do
      desc "convert [FROM]", "Convert a file"
      option :settings, type: :string, desc: "Path of settings file", banner: "path"
      option :reset, type: :boolean, desc: "Reset database before converting data"
      def convert(from)
        validate_from!(from)
        validate_settings_path!(settings)

        ::Migrations.load_rails_environment

        puts "Converting..."

        ::Migrations::IntermediateDB::Migrator.reset!("/tmp/converter/intermediate.db")
        ::Migrations::IntermediateDB::Migrator.migrate("/tmp/converter/intermediate.db")
      end

      private

      def validate_from!(from)
        converter_names = ::Migrations::Converters.converter_names

        if converter_names.exclude?(from)
          raise Thor::Error,
                "Unknown converter name: #{from}\nValid names are: #{converter_names.join(", ")}"
        end
      end

      def validate_options(options)
        if !File.exist?(options.settings_path)
          prompt.error("Settings file not found: #{options.settings_path}")
          exit(1)
        end

        if File.exist?(OutputDatabase::DEFAULT_PATH)
          options.compatible = compatible_database?(options.from) if options.compatible.nil?
          if !options.reset && !options.compatible
            prompt.error("Incompatible database found")
            exit(1)
          end
        end
      end

      def compatible_database?(type)
        ::Migrations::IntermediateDB::Connection.connect(path) do |db|
          db.get_config_value(CONFIG_CONVERTING_FROM) == type
        end
      rescue Extralite::SQLError
        false
      end

      def default_settings_path(type)
        File.join(Migrations, type, "settings.yml")
      end
    end
  end
end
