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
      schema = load_json_schema
      schemer = JSONSchemer.schema(schema)
      response = schemer.validate(config)

      response.each do |r|
        error_message = r.fetch("error")
        error_message.gsub!(/value at (`.+?`) matches `not` schema/) do
          I18n.t("schema.validator.include_exclude_not_allowed", path: $1)
        end
        @errors << error_message
      end
    end

    def load_json_schema
      schema_path = File.join(::Migrations.root_path, "config", "json_schemas", "db_schema.json")
      JSON.load_file(schema_path)
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
      if !Dir.exist?(schema_file_path)
        @errors << I18n.t("schema.validator.output.schema_file_directory_not_found")
      end

      models_directory = File.expand_path(output_config[:models_directory], ::Migrations.root_path)
      if !Dir.exist?(models_directory)
        @errors << I18n.t("schema.validator.output.models_directory_not_found")
      end

      existing_namespace =
        begin
          Object.const_get(output_config[:models_namespace]).is_a?(Module)
        rescue NameError
          false
        end
      @errors << I18n.t("schema.validator.output.models_namespace_undefined") if !existing_namespace
    end

    def validate_schema_config(config)
      schema_config = config[:schema]
      validate_globally_excluded_tables(schema_config)
      validate_tables(schema_config)
      validate_columns(schema_config)
    end

    def validate_globally_excluded_tables(schema_config)
      excluded_table_names = schema_config.dig(:global, :tables, :exclude)
      return if excluded_table_names.blank?

      existing_table_names = @db.tables
      missing_table_names = excluded_table_names - existing_table_names

      if missing_table_names.any?
        @errors << I18n.t(
          "schema.validator.global.excluded_tables_missing",
          table_names: sort_and_join(missing_table_names),
        )
      end
    end

    def validate_globally_configured_columns(schema_config)
      globally_excluded_column_names = schema_config.dig(:global, :columns, :exclude)
      globally_modified_columns = schema_config.dig(:global, :columns, :modify)

      globally_excluded_table_names = schema_config.dig(:global, :tables, :exclude) || []
      existing_table_names = @db.tables
      configured_table_names = schema_config[:tables].keys.map(&:to_s)
      excluded_table_names = schema_config.dig(:global, :tables, :exclude) || []

      all_table_names =
        (existing_table_names - globally_excluded_table_names - excluded_table_names) &
          configured_table_names
      all_column_names =
        all_table_names.flat_map { |table_name| @db.columns(table_name).map(&:name) }.uniq.to_set

      excluded_missing_column_names =
        globally_excluded_column_names.reject do |column_name|
          all_column_names.include?(column_name)
        end
      @errors << I18n.t() if excluded_missing_column_names.any?
    end

    def validate_tables(schema_config)
      existing_table_names = @db.tables
      configured_table_names = schema_config[:tables].keys.map(&:to_s)
      excluded_table_names = schema_config.dig(:global, :tables, :exclude) || []

      if (table_names = configured_table_names & excluded_table_names).any?
        @errors << I18n.t(
          "schema.validator.global.excluded_tables_used",
          table_names: sort_and_join(table_names),
        )
      end

      existing_table_names.sort.each do |table_name|
        if !configured_table_names.include?(table_name) &&
             !excluded_table_names.include?(table_name)
          @errors << I18n.t("schema.validator.table_not_configured", table_name:)
        end
      end
    end

    def validate_columns(schema_config)
      globally_excluded_column_names = schema_config.dig(:global, :columns, :exclude) || []

      schema_config[:tables].each_pair do |table_name, table_config|
        validate_columns_of_table(
          table_name.to_s,
          table_config[:columns],
          globally_excluded_column_names,
        )
      end
    end

    def validate_columns_of_table(table_name, columns, globally_excluded_column_names)
      existing_column_names = @db.columns(table_name).map { |c| c.name }.sort.to_set
      added_column_names = columns[:add]&.map { |column| column[:name] } || []
      modified_column_names = columns[:modify]&.map { |column| column[:name] } || []
      included_column_names = columns[:include] || []
      excluded_column_names = columns[:exclude] || []

      added_column_names.each do |column_name|
        if existing_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.added_existing_column", column_name:, table_name:)
        end
      end

      included_column_names.each do |column_name|
        if !existing_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.included_column_missing", column_name:, table_name:)
        end
      end

      excluded_column_names.each do |column_name|
        if !existing_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.excluded_column_missing", column_name:, table_name:)
        end
      end

      modified_column_names.each do |column_name|
        if !existing_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.modified_column_missing", column_name:, table_name:)
        elsif included_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.modified_column_included", column_name:, table_name:)
        elsif excluded_column_names.include?(column_name)
          @errors << I18n.t("schema.validator.modified_column_excluded", column_name:, table_name:)
        end
      end

      if excluded_column_names.empty?
        unconfigured_column_names =
          existing_column_names - included_column_names - modified_column_names
        if unconfigured_column_names.any?
          @errors << I18n.t(
            "schema.validator.columns_not_configured",
            column_names: unconfigured_column_names.sort.join(", "),
            table_name:,
          )
        end
      end

      configured_column_names =
        if excluded_column_names.any?
          existing_column_names - excluded_column_names - globally_excluded_column_names +
            modified_column_names + added_column_names
        else
          included_column_names + modified_column_names - globally_excluded_column_names +
            added_column_names
        end

      if configured_column_names.empty?
        @errors << I18n.t("schema.validator.no_columns_configured", table_name:)
      end
    end

    def validate_plugins(config)
      plugin_names = config[:plugins]
      all_plugin_names = Discourse.plugins.map(&:name)

      if (additional_plugins = all_plugin_names.difference(plugin_names)).any?
        @errors << I18n.t(
          "schema.validator.plugins.additional_installed",
          plugin_names: additional_plugins.sort.join(", "),
        )
      end

      if (missing_plugins = plugin_names.difference(all_plugin_names)).any?
        @errors << I18n.t(
          "schema.validator.plugins.not_installed",
          plugin_names: missing_plugins.sort.join(", "),
        )
      end
    end

    def sort_and_join(values)
      values.sort.join(", ")
    end
  end
end
