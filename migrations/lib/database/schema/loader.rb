# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader
    attr_reader :errors

    def initialize(schema_config)
      @schema_config = schema_config
      @global = GlobalConfig.new(@schema_config)
      @db = ActiveRecord::Base.connection

      @errors = []
    end

    def load_schema
      schema = []
      existing_table_names = @db.tables.to_set

      @schema_config[:tables].sort.each do |table_name, config|
        table_name = table_name.to_s

        if config[:copy_of].present?
          table_alias = table_name
          table_name = config[:copy_of]
        else
          next if @global.excluded_table_name?(table_name)
        end

        if existing_table_names.include?(table_name)
          schema << table(table_name, config, table_alias)
        end
      end

      schema
    end

    private

    def table(table_name, config, table_alias = nil)
      primary_key_column_names = @db.primary_keys(table_name)
      columns =
        filtered_columns_of(table_name, config).map do |column|
          Column.new(
            name: column.name,
            datatype: datatype_for(column),
            nullable: column.null || column.default,
            max_length: column.type == :text ? column.limit : nil,
            is_primary_key: primary_key_column_names.include?(column.name),
          )
        end

      Table.new(table_alias || table_name, columns, indexes(config), primary_key_column_names)
    end

    def filtered_columns_of(table_name, config)
      columns_by_name = @db.columns(table_name).index_by(&:name)
      columns_by_name.except!(*@global.excluded_column_names)

      if (included_columns = config.dig(:columns, :include))
        columns_by_name.slice!(*included_columns)
      elsif (excluded_columns = config.dig(:columns, :exclude))
        columns_by_name.except!(*excluded_columns)
      end

      columns_by_name.values
    end

    def datatype_for(column)
      datatype = @global.modified_datatype(column.name) || column.type

      case datatype
      when :binary
        :blob
      when :string, :enum, :uuid
        :text
      when :jsonb
        :json
      when :boolean, :date, :datetime, :float, :inet, :integer, :numeric, :json, :text
        datatype
      else
        raise "Unknown datatype: #{datatype}"
      end
    end

    def indexes(config)
      config[:indexes]&.map do |index|
        Index.new(
          name: index[:name],
          column_names: Array.wrap(index[:columns]),
          unique: index.fetch(:unique, false),
          condition: index[:condition],
        )
      end
    end
  end
end
