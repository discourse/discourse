# frozen_string_literal: true

module Migrations::Database::Schema
  class EnumResolver
    class EnumSourceError < StandardError
    end

    def initialize(config, allowed_classes: [])
      @config = config || {}
      @allowed_classes = allowed_classes
    end

    def resolve
      @config.map do |name, entry|
        name = name.to_s
        values = resolve_values(name, entry)
        EnumDefinition.new(name:, values:)
      end
    end

    private

    def resolve_values(name, entry)
      base_values =
        if entry[:values]
          normalize_yaml_values(entry[:values])
        elsif entry[:model] && entry[:source]
          fetch_model_values(entry)
        else
          raise EnumSourceError, "Enum #{name} must have either :values or :model+source"
        end

      extra = entry[:extra]
      base_values = merge_extra(base_values, extra) if extra

      base_values
    end

    def normalize_yaml_values(values)
      case values
      when Array
        values.each_with_index.to_h
      when Hash
        values.dup
      else
        raise EnumSourceError, "Invalid :values format: #{values.inspect}"
      end
    end

    def fetch_model_values(entry)
      klass = safe_constantize(entry[:model])
      source = entry[:source].to_sym
      only_keys = Array(entry[:only])

      if !klass.is_a?(Class)
        raise EnumSourceError,
              "#{entry[:model]} resolved to #{klass.class.name}, which is not a class"
      end

      if !(klass < ActiveRecord::Base || @allowed_classes.include?(klass))
        raise EnumSourceError,
              "Class #{klass} is not an ActiveRecord model and not in allowed_classes"
      end

      values =
        if klass.respond_to?(source)
          klass.public_send(source)
        elsif valid_constant_name?(source) && klass.const_defined?(source)
          klass.const_get(source)
        else
          raise EnumSourceError, "Class #{klass} does not define constant or class method #{source}"
        end

      enum_hash =
        case values
        when Hash
          values.transform_keys(&:to_s)
        when Array
          values.each_with_index.to_h.transform_keys(&:to_s)
        else
          raise EnumSourceError, "#{klass}.#{source} must return a Hash or an Array"
        end

      if only_keys.any?
        enum_hash.select { |k, _| only_keys.include?(k) }
      else
        enum_hash
      end
    end

    def merge_extra(base_values, extra)
      extra.each_with_object(base_values.dup) do |(k, v), h|
        h[k] = if v.nil?
          h.values.max.to_i + 1
        else
          v
        end
      end
    end

    def safe_constantize(name)
      name.constantize
    rescue NameError
      raise EnumSourceError, "Model not found: #{name}"
    end

    def valid_constant_name?(name)
      /[[:upper:]]/.match(name.to_s)
    end
  end
end
