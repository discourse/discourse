# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader
    def initialize(schema_config)
      @schema_config = schema_config
      @global = GlobalConfig.new(@schema_config)
    end

    def load_schema
      @db = ActiveRecord::Base.lease_connection

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

      @db = nil
      ActiveRecord::Base.release_connection

      schema
    end

    private

    def table(table_name, config, table_alias = nil)
      primary_key_column_names =
        config[:primary_key_column_names].presence || @db.primary_keys(table_name)

      columns =
        filtered_columns_of(table_name, config).map do |column|
          Column.new(
            name: name_for(column),
            datatype: datatype_for(column),
            nullable: nullable_for(column, config),
            max_length: column.type == :text ? column.limit : nil,
            is_primary_key: primary_key_column_names.include?(column.name),
          )
        end + added_columns(config, primary_key_column_names)

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

    def added_columns(config, primary_key_column_names)
      columns = config.dig(:columns, :add) || []
      columns.map do |column|
        datatype = column[:datatype].to_sym
        Column.new(
          name: column[:name],
          datatype:,
          nullable: column.fetch(:nullable, true),
          max_length: datatype == :text ? column[:max_length] : nil,
          is_primary_key: primary_key_column_names.include?(column[:name]),
        )
      end
    end

    def name_for(column)
      @global.modified_name(column.name) || column.name
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

    def nullable_for(column, config)
      modified_column = config.dig(:columns, :modify)&.find { |col| col[:name] == column.name }
      return modified_column[:nullable] if modified_column&.key?(:nullable)

      global_nullable = @global.modified_nullable(column.name)
      return global_nullable unless global_nullable.nil?

      column.null || column.default.present?
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
