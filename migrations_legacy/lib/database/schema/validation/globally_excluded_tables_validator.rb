# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class GloballyExcludedTablesValidator < BaseValidator
    def validate
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude)
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
  end
end
