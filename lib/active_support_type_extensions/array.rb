# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Array < ActiveModel::Type::Value
    def serializable?(_)
      false
    end

    def cast_value(value)
      case value
      when String
        cast_value(value.split(/,(?!.*\|)|\|(?!.*,)/))
      when ::Array
        value.map { |item| Integer(item, exception: false) || item }
      else
        ::Array.wrap(value)
      end
    end
  end
end
