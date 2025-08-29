# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader
    ALLOWED_ENUM_CLASSES = [UploadCreator].freeze

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
      EnumResolver.new(@schema_config[:enums], allowed_classes: ALLOWED_ENUM_CLASSES).resolve
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
          ColumnDefinition.new(
            name: name_for(column),
            datatype: datatype_for(column, config),
            nullable: nullable_for(column, config),
            max_length: column.type == :text ? column.limit : nil,
            is_primary_key: primary_key_column_names.include?(column.name),
          )
        end + added_columns(config, primary_key_column_names)

      TableDefinition.new(
        table_alias || table_name,
        columns,
        indexes(config),
        primary_key_column_names,
      )
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
        enum = column[:enum]
        datatype = enum ? :integer : column[:datatype].to_sym
        ColumnDefinition.new(
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

    def datatype_for(column, config)
      datatype =
        if (modified_column = modified_column_for(column, config))
          modified_column[:enum] ? :integer : modified_column[:datatype]&.to_sym
        end

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

    def nullable_for(column, config)
      modified_column = modified_column_for(column, config)
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
  end
end
