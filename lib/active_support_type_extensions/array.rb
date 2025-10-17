# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Array < ActiveModel::Type::Value
    attr_reader :compact_blank

    def initialize(compact_blank: false)
      super()
      @compact_blank = compact_blank
    end

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
      end.tap { _1.compact_blank! if compact_blank }
    end
  end
end
