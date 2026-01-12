# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Hash < ActiveModel::Type::Value
    def serializable?(_)
      false
    end

    def cast_value(value)
      case value
      when ::Hash
        value
      when String
        parse_json_string(value)
      when NilClass
        nil
      else
        value.respond_to?(:to_h) ? value.to_h : {}
      end
    end

    private

    def parse_json_string(value)
      return {} if value.blank?

      ::JSON.parse(value)
    rescue JSON::ParserError
      {}
    end
  end
end
