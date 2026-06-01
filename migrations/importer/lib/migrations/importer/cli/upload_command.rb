# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class UploadCommand < Migrations::CLI::Command
        requires_rails!

        self.description = "Import media uploads referenced by the IntermediateDB"

        options do
          option "-h/--help", "Print out help."
          option "--settings <path>",
                 "Path of the uploads settings file.",
                 default: "./migrations/config/upload.yml"
          option "--fix-missing", "Fix missing uploads."
          option "--optimize", "Generate optimized images."
        end

        def call
          return print_usage if @options[:help]

          puts "Starting uploads..."

          adjust_db_pool_size

          settings = load_settings
          Uploads::Uploads.perform!(settings)

          puts ""
        end

        private

        def load_settings
          path = @options[:settings]
          raise NoSettingsFound, "Settings file not found: #{path}" unless File.exist?(path)

          settings = SettingsParser.parse!(path)
          settings[:fix_missing] = true if @options[:fix_missing]
          settings[:create_optimized_images] = true if @options[:optimize]
          settings
        end

        def adjust_db_pool_size
          max_db_connections = ::DB.query_single("SHOW max_connections").first.to_i
          current_size = ActiveRecord::Base.connection_pool.size

          if current_size < max_db_connections
            db_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
            db_config[:pool] = max_db_connections
            ActiveRecord::Base.establish_connection(db_config)

            puts "Adjusted DB pool size from #{current_size} to #{ActiveRecord::Base.connection_pool.size}"
          else
            puts "DB pool size: #{current_size} (max connections: #{max_db_connections})"
          end
        end
      end
    end
  end
end
