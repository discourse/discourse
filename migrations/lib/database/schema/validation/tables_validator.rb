# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class TablesValidator < BaseValidator
    def validate
      existing_table_names = @db.tables
      configured_table_names = @schema_config[:tables].keys.map(&:to_s)
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []

      if (table_names = configured_table_names & excluded_table_names).any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_tables_configured",
          table_names: sort_and_join(table_names),
        )
      end

      if (table_names = existing_table_names - configured_table_names - excluded_table_names).any?
        @errors << I18n.t(
          "schema.validator.tables.not_configured",
          table_names: sort_and_join(table_names),
        )
      end
    end
  end
end
