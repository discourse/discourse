# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  ColumnOptions = Data.define(:type, :required, :max_length, :rename_to)
  AddedColumn = Data.define(:name, :type, :required, :enum)
  IndexConfig = Data.define(:column_names, :name, :unique, :condition)
  ConstraintConfig = Data.define(:name, :type, :condition)

  TableDef =
    Data.define(
      :name,
      :source_table_name,
      :primary_key_columns,
      :included_column_names,
      :column_options,
      :added_columns,
      :indexes,
      :constraints,
      :ignored_columns_map,
      :ignore_plugin_columns,
      :plugin_name,
    ) do
      def column_options_for(col)
        column_options[col.to_sym]
      end

      def ignored_column_names
        ignored_columns_map.keys
      end

      def ignore_reason_for(col)
        ignored_columns_map[col.to_sym]
      end

      def ignore_plugin_columns?
        ignore_plugin_columns
      end
    end

  class TableBuilder
    def initialize(name)
      @name = name.to_sym
      @source_table_name = @name
      @primary_key_cols = nil
      @included_columns = nil
      @column_options = {}
      @added_columns = []
      @indexes = []
      @constraints = []
      @ignored_columns = {}
      @ignore_plugin_columns = false
      @plugin_name = nil
    end

    def copy_structure_from(table)
      @source_table_name = table.to_sym
    end

    def primary_key(*cols)
      @primary_key_cols = cols.flatten.map(&:to_sym)
    end

    def include(*cols)
      @included_columns ||= []
      @included_columns.concat(cols.flatten.map(&:to_sym))
    end

    def column(name, type = nil, **opts, &block)
      name = name.to_sym
      if block
        builder = ColumnOptionsBuilder.new
        builder.instance_eval(&block)
        @column_options[name] = builder.build
      else
        @column_options[name] = ColumnOptions.new(
          type: type&.to_sym || opts[:type]&.to_sym,
          required: opts[:required],
          max_length: opts[:max_length],
          rename_to: opts[:rename_to]&.to_sym,
        )
      end
    end

    def add_column(name, type, required: false, enum: nil)
      @added_columns << AddedColumn.new(name: name.to_sym, type: type.to_sym, required:, enum:)
    end

    def ignore(col, reason)
      if reason.nil? || reason.strip.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Ignored column :#{col} in table :#{@name} must have a reason."
      end
      @ignored_columns[col.to_sym] = reason
    end

    def index(*cols, name: nil, unique: false, where: nil)
      cols = cols.flatten.map(&:to_sym)
      index_name = name || generate_index_name(cols, unique)
      @indexes << IndexConfig.new(
        column_names: cols,
        name: index_name.to_sym,
        unique:,
        condition: where,
      )
    end

    def unique_index(*cols, name: nil, where: nil)
      index(*cols, name:, unique: true, where:)
    end

    def check(name, condition)
      @constraints << ConstraintConfig.new(name: name.to_sym, type: :check, condition:)
    end

    def plugin(name)
      @plugin_name = name.to_s
    end

    def ignore_plugin_columns!
      @ignore_plugin_columns = true
    end

    def build
      TableDef.new(
        name: @name,
        source_table_name: @source_table_name,
        primary_key_columns: @primary_key_cols,
        included_column_names: @included_columns,
        column_options: @column_options.freeze,
        added_columns: @added_columns.freeze,
        indexes: @indexes.freeze,
        constraints: @constraints.freeze,
        ignored_columns_map: @ignored_columns.freeze,
        ignore_plugin_columns: @ignore_plugin_columns,
        plugin_name: @plugin_name,
      )
    end

    private

    def generate_index_name(cols, unique)
      prefix = unique ? "idx_unique" : "idx"
      :"#{prefix}_#{@name}_#{cols.join("_")}"
    end
  end

  class ColumnOptionsBuilder
    def initialize
      @type = nil
      @required = nil
      @max_length = nil
      @rename_to = nil
    end

    def type(value)
      @type = value.to_sym
    end

    def required(value = true)
      @required = value
    end

    def max_length(value)
      @max_length = value
    end

    def rename_to(value)
      @rename_to = value.to_sym
    end

    def build
      ColumnOptions.new(
        type: @type,
        required: @required,
        max_length: @max_length,
        rename_to: @rename_to,
      )
    end
  end
end
