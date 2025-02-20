# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class GloballyConfiguredColumnsValidator < BaseValidator
    def validate
      globally_excluded_column_names = @schema_config.dig(:global, :columns, :exclude)
      globally_modified_columns = @schema_config.dig(:global, :columns, :modify)

      globally_excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []
      existing_table_names = @db.tables
      configured_table_names = @schema_config[:tables].keys.map(&:to_s)
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []

      all_table_names =
        (existing_table_names - globally_excluded_table_names - excluded_table_names) &
          configured_table_names
      all_column_names =
        all_table_names.flat_map { |table_name| @db.columns(table_name).map(&:name) }.uniq.to_set

      if globally_excluded_column_names
        excluded_missing_column_names =
          globally_excluded_column_names.reject do |column_name|
            all_column_names.include?(column_name)
          end

        if excluded_missing_column_names.any?
          @errors << I18n.t(
            "schema.validator.global.excluded_columns_missing",
            column_names: sort_and_join(excluded_missing_column_names),
          )
        end
      end

      if globally_modified_columns
        excluded_missing_column_names =
          globally_modified_columns.reject { |column_name| all_column_names.include?(column_name) }

        if excluded_missing_column_names.any?
          @errors << I18n.t(
            "schema.validator.global.excluded_columns_missing",
            column_names: sort_and_join(excluded_missing_column_names),
          )
        end
      end
    end
  end
end
