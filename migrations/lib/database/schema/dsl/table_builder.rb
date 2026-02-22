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
      :forced_column_names,
      :column_options,
      :added_columns,
      :indexes,
      :constraints,
      :ignored_columns_map,
      :ignore_plugin_columns,
      :ignore_plugin_names,
      :model_mode,
    ) do
      def column_options_for(col)
        column_options[col.to_s]
      end

      def ignored_column_names
        ignored_columns_map.keys
      end

      def ignore_reason_for(col)
        ignored_columns_map[col.to_s]
      end

      def ignore_plugin_columns?
        ignore_plugin_columns
      end
    end

  VALID_MODEL_MODES = %i[extended manual].freeze

  class TableBuilder
    def initialize(name)
      @name = name.to_s
      @source_table_name = @name
      @primary_key_cols = nil
      @included_columns = nil
      @include_all = false
      @column_options = {}
      @added_columns = []
      @indexes = []
      @constraints = []
      @ignored_columns = {}
      @forced_columns = []
      @ignore_plugin_columns = false
      @ignore_plugin_names = nil
      @model_mode = nil
    end

    def copy_structure_from(table)
      @source_table_name = table.to_s
    end

    def synthetic!
      @source_table_name = nil
    end

    def primary_key(*cols)
      @primary_key_cols = cols.flatten.map(&:to_s)
    end

    def include(*cols)
      @included_columns ||= []
      @included_columns.concat(cols.flatten.map(&:to_s))
    end

    def include_all
      @include_all = true
    end

    def include!(*cols)
      @forced_columns.concat(cols.flatten.map(&:to_s))
    end

    def column(name, type = nil, **opts, &block)
      name = name.to_s
      if block
        builder = ColumnOptionsBuilder.new
        builder.instance_eval(&block)
        @column_options[name] = builder.build
      else
        @column_options[name] = ColumnOptions.new(
          type: type&.to_s || opts[:type]&.to_s,
          required: opts[:required],
          max_length: opts[:max_length],
          rename_to: opts[:rename_to]&.to_s,
        )
      end
    end

    def add_column(name, type, required: false, enum: nil)
      enum = enum.to_s if enum
      @added_columns << AddedColumn.new(name: name.to_s, type: type.to_s, required:, enum:)
    end

    def ignore(*cols, reason: nil)
      cols.flatten.each { |col| @ignored_columns[col.to_s] = reason }
    end

    def index(*cols, name: nil, unique: false, where: nil)
      cols = cols.flatten.map(&:to_s)
      index_name = name || generate_index_name(cols, unique)
      @indexes << IndexConfig.new(
        column_names: cols,
        name: index_name.to_s,
        unique:,
        condition: where,
      )
    end

    def unique_index(*cols, name: nil, where: nil)
      index(*cols, name:, unique: true, where:)
    end

    def check(name, condition)
      @constraints << ConstraintConfig.new(name: name.to_s, type: :check, condition:)
    end

    def ignore_plugin_columns!(*plugin_names)
      @ignore_plugin_columns = true
      @ignore_plugin_names =
        plugin_names.flatten.map do |name|
          ::Migrations::Database::Schema::Helpers.normalize_plugin_name(name)
        end if plugin_names.any?
    end

    def model(mode)
      mode = mode.to_sym
      if VALID_MODEL_MODES.exclude?(mode)
        raise Migrations::Database::Schema::ConfigError,
              "Invalid model mode :#{mode} for table :#{@name}. Valid: #{VALID_MODEL_MODES.join(", ")}"
      end
      @model_mode = mode
    end

    def build
      if @source_table_name && @included_columns.nil? && !@include_all && @ignored_columns.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Table :#{@name} must use `include_all`, `include`, or `ignore` to specify which columns to include"
      end

      if @source_table_name.nil? && (@included_columns || @include_all)
        raise Migrations::Database::Schema::ConfigError,
              "Table :#{@name} is synthetic and cannot use `include` or `include_all`"
      end

      if @included_columns && @ignored_columns.any?
        overlap = @included_columns & @ignored_columns.keys
        if overlap.any?
          raise Migrations::Database::Schema::ConfigError,
                "Table :#{@name} has columns that are both included and ignored: #{overlap.join(", ")}"
        end
      end

      if @included_columns && @include_all
        raise Migrations::Database::Schema::ConfigError,
              "Table :#{@name} cannot use both `include` and `include_all`"
      end

      TableDef.new(
        name: @name,
        source_table_name: @source_table_name,
        primary_key_columns: @primary_key_cols,
        included_column_names: @included_columns,
        forced_column_names: @forced_columns.empty? ? nil : @forced_columns.freeze,
        column_options: @column_options.freeze,
        added_columns: @added_columns.freeze,
        indexes: @indexes.freeze,
        constraints: @constraints.freeze,
        ignored_columns_map: @ignored_columns.freeze,
        ignore_plugin_columns: @ignore_plugin_columns,
        ignore_plugin_names: @ignore_plugin_names&.freeze,
        model_mode: @model_mode,
      )
    end

    private

    def generate_index_name(cols, unique)
      prefix = unique ? "idx_unique" : "idx"
      "#{prefix}_#{@name}_#{cols.join("_")}"
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
      @type = value.to_s
    end

    def required(value = true)
      @required = value
    end

    def max_length(value)
      @max_length = value
    end

    def rename_to(value)
      @rename_to = value.to_s
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
