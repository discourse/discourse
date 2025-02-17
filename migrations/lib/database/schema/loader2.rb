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
      table_names = @schema_config.dig(:global, :tables, :exclude)
      @globally_excluded_table_names = table_names.to_set if table_names.present?
    end

    def load_globally_excluded_column_names
      column_names = @schema_config.dig(:global, :columns, :exclude)
      @globally_excluded_column_names = column_names.to_set if column_names.present?
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

    def load_filtered_tables
      @schema_config[:tables].sort.each do |table_name, table_config|
        next if @globally_excluded_table_names.include?(table_name)
      end
    end

    def load_tables
      existing_table_names = (@db.tables.to_set - @globally_excluded_table_names).sort

      @schema_config[:tables].sort.each do |table_name, config|
        table_name = table_name.to_s
        config ||= {}
        schema << table(table_name, config) if existing_table_names.include?(table_name)
      end
    end
  end
end
