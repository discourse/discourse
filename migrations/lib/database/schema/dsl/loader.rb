# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module DSL
        class Loader
          def initialize(config_path)
            @config_path = config_path
          end

          def load!
            validate_config_path!
            load_file("config.rb")
            load_file("conventions.rb", optional: true)
            load_file("ignored.rb", optional: true)
            load_enum_files
            load_table_files
          end

          private

          def validate_config_path!
            if !File.directory?(@config_path)
              raise ConfigError, "Schema config directory not found: #{@config_path}"
            end
          end

          def load_file(filename, optional: false)
            path = File.join(@config_path, filename)
            if File.exist?(path)
              load_with_error_handling(path)
            elsif !optional
              raise ConfigError, "Required config file not found: #{path}"
            end
          end

          def load_enum_files
            dir = File.join(@config_path, "enums")
            return unless File.directory?(dir)
            Dir[File.join(dir, "*.rb")].sort.each { |path| load_with_error_handling(path) }
          end

          def load_table_files
            dir = File.join(@config_path, "tables")
            return unless File.directory?(dir)
            Dir[File.join(dir, "*.rb")].sort.each { |path| load_with_error_handling(path) }
          end

          def load_with_error_handling(path)
            Kernel.load(path)
          rescue ConfigError
            raise
          rescue StandardError => e
            raise ConfigError, "Error loading #{path}: #{e.message}"
          end
        end
      end
    end
  end
end
