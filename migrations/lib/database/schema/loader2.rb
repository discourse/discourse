# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader2
    def initialize(schema_config)
      @schema_config = schema_config
      @db = ActiveRecord::Base.connection

      @existing_table_names = @db.tables.sort.to_set

      @globally_excluded_table_names = Set.new
      @globally_excluded_column_names = Set.new
      @globally_modified_columns = {}
      @errors = []
    end

    def load_schema
      load_globally_excluded_table_names
      load_globally_excluded_column_names
      load_globally_modified_columns

      load_tables
    end

    private

    def load_globally_excluded_table_names
      excluded_table_names = @schema_config.dig(:global, :tables, :exclude)
      return if excluded_table_names.blank?

      @globally_excluded_table_names = Set.new(excluded_table_names)
    end

    def load_globally_excluded_column_names
      excluded_column_names = @schema_config.dig(:global, :columns, :exclude)
      return if excluded_column_names.blank?

      @globally_excluded_column_names = Set.new(excluded_column_names)
    end

    def load_globally_modified_columns
      modified_columns = @schema_config.dig(:global, :columns, :modify)
      return if modified_columns.blank?

      @globally_modified_columns =
        modified_columns
          .map do |column|
            name_regex =
              begin
                column[:name_regex].presence&.then { |regex_string| Regexp.new(regex_string) }
              rescue RegexpError => e
                @errors << I18n.t("schema.validator.invalid_name_regex", message: e.message)
              end

            [column[:name], column.merge(name_regex:)]
          end
          .to_h
    end

    def load_tables
      existing_table_names = (@db.tables.to_set - @globally_excluded_table_names).sort

      @schema_config[:tables].sort.each do |table_name|
        table_name = table_name.to_s
        config ||= {}
        schema << table(table_name, config) if existing_table_names.include?(table_name)
      end
    end
  end
end
