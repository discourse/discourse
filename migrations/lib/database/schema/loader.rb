# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader
    def initialize(schema_config)
      @schema_config = schema_config
      @global = GlobalConfig.new(@schema_config)
    end

    def load_schema
      enums = load_enums
      tables = load_tables
      Definition.new(tables:, enums:)
    end

    private

    def load_enums
      enums = EnumResolver.new(@schema_config[:enums]).resolve
      @enums_by_name = enums.index_by(&:name)
      enums
    end

    def load_tables
      @db = ActiveRecord::Base.lease_connection

      tables = []
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
          tables << table(table_name, config, table_alias)
        end
      end

      @db = nil
      ActiveRecord::Base.release_connection

      tables
    end

    def table(table_name, config, table_alias = nil)
      primary_key_column_names =
        config[:primary_key_column_names].presence || @db.primary_keys(table_name)

      columns =
        filtered_columns_of(table_name, config).map do |column|
          modified_column = modified_column_for(column, config)
          enum = @enums_by_name[modified_column[:enum]] if modified_column&.key?(:enum)

          ColumnDefinition.new(
            name: name_for(column),
            datatype: datatype_for(column, modified_column, enum),
            nullable: nullable_for(column, modified_column),
            max_length: column.type == :text ? column.limit : nil,
            is_primary_key: primary_key_column_names.include?(column.name),
            enum:,
          )
        end + added_columns(config, primary_key_column_names)

      TableDefinition.new(
        table_alias || table_name,
        columns,
        indexes(config),
        primary_key_column_names,
        constraints(config),
      )
    end

    def filtered_columns_of(table_name, config)
      columns_by_name = @db.columns(table_name).index_by(&:name)
      globally_excluded_columns = @global.excluded_column_names

      if (included_columns = config.dig(:columns, :include))
        modified_columns = config.dig(:columns, :modify)&.map { |c| c[:name] }
        included_columns = included_columns + modified_columns if modified_columns
        globally_excluded_columns -= included_columns
        columns_by_name.slice!(*included_columns)
      elsif (excluded_columns = config.dig(:columns, :exclude))
        columns_by_name.except!(*excluded_columns)
      end

      columns_by_name.except!(*globally_excluded_columns)
      columns_by_name.values
    end

    def added_columns(config, primary_key_column_names)
      columns = config.dig(:columns, :add) || []
      columns.map do |column|
        enum = @enums_by_name[column[:enum]] if column[:enum]
        datatype = enum ? enum.datatype : column[:datatype].to_sym

        ColumnDefinition.new(
          name: column[:name],
          datatype:,
          nullable: column.fetch(:nullable, true),
          max_length: datatype == :text ? column[:max_length] : nil,
          is_primary_key: primary_key_column_names.include?(column[:name]),
          enum:,
        )
      end
    end

    def name_for(column)
      @global.modified_name(column.name) || column.name
    end

    def datatype_for(column, modified_column, enum)
      datatype = enum.datatype if enum
      datatype ||= modified_column[:datatype]&.to_sym if modified_column
      datatype ||= @global.modified_datatype(column.name) || column.type

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

    def modified_column_for(column, config)
      config.dig(:columns, :modify)&.find { |col| col[:name] == column.name }
    end

    def nullable_for(column, modified_column)
      return modified_column[:nullable] if modified_column&.key?(:nullable)

      global_nullable = @global.modified_nullable(column.name)
      return global_nullable unless global_nullable.nil?

      column.null || column.default.present?
    end

    def indexes(config)
      config[:indexes]&.map do |index|
        IndexDefinition.new(
          name: index[:name],
          column_names: Array.wrap(index[:columns]),
          unique: index.fetch(:unique, false),
          condition: index[:condition],
        )
      end
    end

    def constraints(config)
      config[:constraints]&.map do |constraint|
        ConstraintDefinition.new(
          name: constraint[:name],
          type: constraint.fetch(:type, :check).to_sym,
          condition: constraint[:condition],
        )
      end
    end
  end
end
