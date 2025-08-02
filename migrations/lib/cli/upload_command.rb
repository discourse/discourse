# frozen_string_literal: true

module Migrations::CLI
  class UploadCommand
    def initialize(options)
      @options = options
    end

    def execute
      puts "Starting uploads..."

      ::Migrations.load_rails_environment(quiet: true)

      adjust_db_pool_size

      validate_settings_file!
      settings = load_settings

      ::Migrations::Uploader::Uploads.perform!(settings)

      puts ""
    end

    private

    def load_settings
      settings = ::Migrations::SettingsParser.parse!(@options.settings)
      merge_settings_from_cli_args!(settings)

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

    def adjust_db_pool_size
      max_db_connections = DB.query_single("SHOW max_connections").first.to_i
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
