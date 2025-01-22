# frozen_string_literal: true

require "json_schemer"

module Migrations::Database::Schema
  class ConfigValidator
    attr_reader :errors

    def initialize
      @db = ActiveRecord::Base.connection
      @errors = []
    end

    def validate(config)
      @errors.clear

      validate_with_json_schema(config)
      return self if has_errors?

      validate_config(config)

      self
    end

    def has_errors?
      @errors.any?
    end

    private

    def validate_with_json_schema(config)
      schema_path = File.join(::Migrations.root_path, "config", "json_schemas", "db_schema.json")
      schema = JSON.load_file(schema_path)

      schemer = JSONSchemer.schema(schema)
      response = schemer.validate(config)

      response.each { |r| @errors << r.fetch("error") }
    end

    def validate_config(config)
      validate_output_config(config)
      validate_schema_config(config)
      validate_plugins(config)
    end

    def validate_output_config(config)
      output_config = config[:output]

      schema_file_path = File.dirname(output_config[:schema_file])
      schema_file_path = File.expand_path(schema_file_path, ::Migrations.root_path)
      @errors << "Directory of `schema_file` does not exist" if !Dir.exist?(schema_file_path)

      models_directory = File.expand_path(output_config[:models_directory], ::Migrations.root_path)
      @errors << "`models_directory` does not exist" if !Dir.exist?(models_directory)

      existing_namespace =
        begin
          Object.const_get(output_config[:models_namespace]).is_a?(Module)
        rescue NameError
          false
        end
      @errors << "`models_namespace` is not defined" if !existing_namespace
    end

    def validate_schema_config(config)
      schema_config = config[:schema]
      validate_excluded_tables(schema_config)
      validate_tables(schema_config)
    end

    def validate_excluded_tables(schema_config)
      excluded_table_names = schema_config.dig(:global, :tables, :exclude)
      return if excluded_table_names.blank?

      existing_table_names = @db.tables.to_set

      excluded_table_names.sort.each do |table_name|
        if !existing_table_names.delete?(table_name)
          @errors << "Excluded table does not exist: #{table_name}"
        end
      end
    end

    def validate_tables(schema_config)
      existing_table_names = @db.tables
      configured_table_names = schema_config[:tables].keys.map(&:to_s).to_set
      excluded_table_names = schema_config.dig(:global, :tables, :exclude) || []

      excluded_table_names.sort.each do |table_name|
        if configured_table_names.include?(table_name)
          @errors << "Excluded table can't be configured in `schema/tables` section: #{table_name}"
        end
      end

      existing_table_names.sort.each do |table_name|
        if !configured_table_names.include?(table_name) &&
             !excluded_table_names.include?(table_name)
          @errors << "Table missing from configuration file: #{table_name}"
        end
      end
    end

    def validate_plugins(config)
      plugin_names = config[:plugins]
      all_plugin_names = Discourse.plugins.map(&:name)

      if (additional_plugins = all_plugin_names.difference(plugin_names)).any?
        @errors << "Additional plugins installed. Uninstall them or add to configuration: #{additional_plugins.sort.join(", ")}"
      end

      if (missing_plugins = plugin_names.difference(all_plugin_names)).any?
        @errors << "Configured plugins not installed: #{missing_plugins.sort.join(", ")}"
      end
    end
  end
end
