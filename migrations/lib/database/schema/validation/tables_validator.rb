# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class TablesValidator < BaseValidator
    def validate
      existing_table_names = @db.tables
      configured_table_names = @schema_config[:tables].keys.map(&:to_s)
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []

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
  end
end
