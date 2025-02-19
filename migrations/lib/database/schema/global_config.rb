# frozen_string_literal: true

module Migrations::Database::Schema
  class GlobalConfig
    attr_reader :excluded_table_names, :excluded_column_names

    def initialize(schema_config)
      @schema_config = schema_config
      @excluded_table_names = load_globally_excluded_table_names.freeze
      @excluded_column_names = load_globally_excluded_column_names.freeze
      @modified_columns = load_globally_modified_columns.freeze
    end

    def excluded_table_name?(table_name)
      @excluded_table_names.include?(table_name)
    end

    def modified_datatype(column_name)
      @modified_columns
        .find { |column| column[:name] == column_name || column[:name_regex]&.match?(column_name) }
        &.fetch(:datatype)
    end

    private

    def load_globally_excluded_table_names
      table_names = @schema_config.dig(:global, :tables, :exclude)
      table_names.present? ? table_names.to_set : Set.new
    end

    def load_globally_excluded_column_names
      column_names = @schema_config.dig(:global, :columns, :exclude)
      column_names.present? ? column_names.to_set : Set.new
    end

    def load_globally_modified_columns
      modified_columns = @schema_config.dig(:global, :columns, :modify)
      return {} if modified_columns.blank?

      modified_columns.map do |column|
        column[:name_regex] = Regexp.new(column[:name_regex]) if column[:name_regex]
        column[:datatype] = column[:datatype].to_sym
        column
      end
    end
  end
end
