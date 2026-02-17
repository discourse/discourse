# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  EnumDef = Data.define(:name, :values, :datatype)

  class EnumBuilder
    def initialize(name)
      @name = name.to_sym
      @values = {}
      @source_code = nil
    end

    def value(name, val)
      @values[name.to_s] = val
    end

    def string_value(name, val)
      @values[name.to_s] = val.to_s
    end

    def source(code)
      @source_code = code
    end

    def build
      values = resolve_values
      if values.empty?
        raise Migrations::Database::Schema::ConfigError,
              "Enum :#{@name} must define at least one value or a source."
      end
      validate_value_types!(values)
      datatype = infer_datatype(values)
      EnumDef.new(name: @name, values: values.freeze, datatype:)
    end

    private

    def resolve_values
      if @source_code
        evaluate_source
      else
        @values
      end
    end

    def evaluate_source
      result = eval(@source_code, TOPLEVEL_BINDING) # rubocop:disable Security/Eval
      case result
      when Hash
        result.transform_keys(&:to_s)
      when Array
        result.each_with_index.to_h { |k, i| [k.to_s, i] }
      else
        raise Migrations::Database::Schema::ConfigError,
              "Enum :#{@name} source must return a Hash or Array, got #{result.class}."
      end
    rescue Migrations::Database::Schema::ConfigError
      raise
    rescue StandardError => e
      raise Migrations::Database::Schema::ConfigError,
            "Enum :#{@name} failed to evaluate source: #{e.message}"
    end

    def infer_datatype(values)
      values.values.first.is_a?(String) ? :text : :integer
    end

    def validate_value_types!(values)
      value_types = values.values.map(&:class).uniq
      if value_types.size > 1
        raise Migrations::Database::Schema::ConfigError,
              "Enum :#{@name} values must all be Strings or all Integers"
      end

      type = value_types.first
      return if type == String || type == Integer

      raise Migrations::Database::Schema::ConfigError,
            "Enum :#{@name} values must be Strings or Integers, got #{type}"
    end
  end
end
