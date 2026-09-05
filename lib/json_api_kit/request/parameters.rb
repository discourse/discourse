# frozen_string_literal: true

module JsonApiKit
  class Request
    class Parameters
      FIELDSETS_AT = %w[fields].freeze
      NAMES_AT = [%w[sort], %w[include], %w[page anchor]].freeze

      def initialize(raw, glossary:)
        @raw = raw
        @glossary = glossary
      end

      def to_h = declared_names(raw, [])

      private

      attr_reader :raw, :glossary

      def declared_names(parameters, path)
        parameters.to_h do |name, value|
          key = declared_at(name, path + [name.to_s])
          [key, declared_value(value, path + [key])]
        end
      end

      def declared_value(value, path)
        return fieldsets(value, path) if path == FIELDSETS_AT
        return names(value, path) if path.in?(NAMES_AT)
        return declared_names(value, path) if value.is_a?(Hash)
        value
      end

      def fieldsets(value, path)
        return value unless value.is_a?(Hash)
        value.to_h { |type, fields| [type, names(fields, path + [type.to_s])] }
      end

      def names(value, path)
        case value
        when Hash
          value.transform_keys { declared_at(it, path + [it.to_s]) }
        when Array
          value.map { names(it, path) }
        when String, Symbol
          declared_at(value, path)
        else
          value
        end
      end

      def declared_at(raw, path)
        glossary.declared_name(raw)
      rescue Glossary::CasingRule::NotAMemberName => error
        raise error.at(ParameterName.new(*path).to_s)
      end
    end
  end
end
