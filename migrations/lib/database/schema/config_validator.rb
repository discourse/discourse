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
      return if has_errors?

      validate_config(config)
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
      validate_plugins(config)
      validate_schema_config(config)
    end

    def validate_plugins(config)
      if (plugin_names = config[:plugins]).nil?
        @errors << "Plugin configuration not found"
        return
      end

      all_plugin_names = Discourse.plugins.map(&:name)

      if (additional_plugins = all_plugin_names.difference(plugin_names)).any?
        @errors << "Additional plugins installed. Uninstall them or add to configuration: #{additional_plugins.join(", ")}"
      end

      if (missing_plugins = plugin_names.difference(all_plugin_names)).any?
        @errors << "Configured plugins not installed: #{missing_plugins.join(", ")}"
      end
    end

    def validate_schema_config(config)
      if (schema_config = config[:schema]).nil?
        @errors << "Schema configuration not found"
        return
      end

      validate_tables(schema_config)
    end

    def validate_tables(schema_config)
      existing_table_names = @db.tables.sort.to_set

      schema_config
        .dig(:global, :tables, :exclude)
        .sort
        .each do |table_name|
          if !existing_table_names.delete?(table_name)
            @errors << "Excluded table does not exist: #{table_name}"
          end
        end

      schema_config[:tables].sort.each do |table_name, _config|
        table_name = table_name.to_s
        if !existing_table_names.delete?(table_name)
          @errors << "Table does not exist: #{table_name}"
        end
      end

      existing_table_names.each do |table_name|
        @errors << "Table missing from configuration file: #{table_name}"
      end
    end
  end
end
