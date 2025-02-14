# frozen_string_literal: true

module Migrations::Database::Schema
  class Loader
    def initialize(schema_config)
      @schema_config = schema_config
      @db = ActiveRecord::Base.connection
    end

    def load_schema
      schema = []
      existing_table_names = filtered_table_names

      @schema_config[:tables].sort.each do |table_name, config|
        table_name = table_name.to_s
        config ||= {}
        schema << table(table_name, config) if existing_table_names.include?(table_name)
      end

      schema
    end

    private

    def filtered_table_names
      @db.tables.to_set - @schema_config.dig(:global, :tables, :exclude).uniq
    end

    def globally_excluded_columns
      @globally_excluded_columns ||= @schema_config.dig(:global, :columns, :exclude) || []
    end

    def globally_modified_columns
      @globally_modified_columns ||=
        (@schema_config.dig(:global, :columns, :modify) || []).each do |c|
          c[:regex] = Regexp.new(c[:regex])
          c[:datatype] = c[:datatype].to_sym
        end
    end

    def filtered_columns_of(table_name, config)
      columns_by_name = @db.columns(table_name).index_by(&:name)

      if (included_columns = config.dig(:columns, :include))
        included_columns.each do |column_name|
          if !columns_by_name.key?(column_name)
            @errors << "Included column not found: #{table_name}.#{column_name}"
          end
        end
        columns_by_name.slice!(*included_columns)
      elsif (excluded_columns = config.dig(:columns, :exclude))
        excluded_columns.each do |column_name|
          if !columns_by_name.delete(column_name)
            @errors << "Excluded column not found: #{table_name}.#{column_name}"
          end
        end
      end

      columns_by_name.except!(*globally_excluded_columns)
      columns_by_name.values
    end

    def table(table_name, config)
      primary_key_column_names = @db.primary_keys(table_name)
      columns =
        filtered_columns_of(table_name, config).map do |c|
          Column.new(
            name: c.name,
            datatype: datatype_for(c),
            nullable: c.null || c.default,
            max_length: c.type == :text ? c.limit : nil,
            is_primary_key: primary_key_column_names.include?(c.name),
          )
        end

      Table.new(table_name, columns, indexes(config), primary_key_column_names)
    end

    def datatype_for(column)
      datatype =
        globally_modified_columns.find { |c| c[:regex].match?(column.name) }&.fetch(:datatype) ||
          column.type

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
