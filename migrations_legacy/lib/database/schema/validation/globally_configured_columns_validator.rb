# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class GloballyConfiguredColumnsValidator < BaseValidator
    def initialize(config, errors, db)
      super
      @global = ::Migrations::Database::Schema::GlobalConfig.new(@schema_config)
    end

    def validate
      all_column_names = calculate_all_column_names

      validate_excluded_column_names(all_column_names)
      validate_modified_columns(all_column_names)
    end

    private

    def calculate_all_column_names
      existing_table_names = @db.tables

      configured_table_names =
        @schema_config[:tables].map do |table_name, table_config|
          table_config[:copy_of] || table_name.to_s
        end

      globally_excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []

      all_table_names = existing_table_names - globally_excluded_table_names - excluded_table_names
      all_table_names = all_table_names.uniq & configured_table_names

      all_table_names.flat_map { |table_name| @db.columns(table_name).map(&:name) }.uniq
    end

    def validate_excluded_column_names(all_column_names)
      globally_excluded_column_names = @global.excluded_column_names
      excluded_missing_column_names = globally_excluded_column_names - all_column_names

      if excluded_missing_column_names.any?
        @errors << I18n.t(
          "schema.validator.global.excluded_columns_missing",
          column_names: sort_and_join(excluded_missing_column_names),
        )
      end
    end

    def validate_modified_columns(all_column_names)
      globally_modified_columns = @global.modified_columns

      excluded_missing_columns =
        globally_modified_columns.reject do |column|
          if column[:name]
            all_column_names.include?(column[:name])
          elsif column[:name_regex]
            all_column_names.any? { |column_name| column[:name_regex]&.match?(column_name) }
          else
            false
          end
        end

      if excluded_missing_columns.any?
        excluded_missing_column_names =
          excluded_missing_columns.map { |column| column[:name_regex_original] || column[:name] }

        @errors << I18n.t(
          "schema.validator.global.modified_columns_missing",
          column_names: sort_and_join(excluded_missing_column_names),
        )
      end
    end
  end
end
