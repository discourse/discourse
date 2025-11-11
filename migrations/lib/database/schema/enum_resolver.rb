# frozen_string_literal: true

module Migrations::Database::Schema
  class EnumResolver
    class EnumSourceError < StandardError
    end

    def initialize(config)
      @config = config || {}
    end

    def resolve
      @config.map do |name, entry|
        name = name.to_s
        values_hash = resolve_values(entry)
        datatype = values_hash.values.first.is_a?(String) ? :text : :integer
        EnumDefinition.new(name:, values: values_hash, datatype:)
      end
    end

    private

    def resolve_values(entry)
      if entry.key?(:values)
        normalize_values(entry[:values])
      elsif entry.key?(:strings)
        normalize_strings(entry[:strings])
      elsif entry.key?(:source)
        fetch_source(entry[:source])
      else
        raise EnumSourceError, "Enum must define :values, :strings, or :source"
      end
    end

    def normalize_values(values)
      case values
      when Array
        values.each_with_index.to_h { |k, i| [k.to_s, i] }
      when Hash
        values.transform_keys(&:to_s)
      else
        raise EnumSourceError, "Invalid :values format: #{values.inspect}"
      end
    end

    def normalize_strings(values)
      case values
      when Array
        values.to_h { |k| [k.to_s, k.to_s] }
      when Hash
        values.transform_keys(&:to_s).transform_values(&:to_s)
      else
        raise EnumSourceError, "Invalid :strings format: #{values.inspect}"
      end
    end

    def fetch_source(source_code)
      values = eval(source_code, TOPLEVEL_BINDING) # rubocop:disable Security/Eval

      case values
      when Hash
        values.transform_keys(&:to_s)
      when Array
        values.each_with_index.to_h { |k, i| [k.to_s, i] }
      else
        raise EnumSourceError, "Eval #{source_code} must return Hash or Array"
      end
    rescue StandardError => e
      raise EnumSourceError, "Failed to evaluate source #{source_code}: #{e.message}"
    end
  end
end
