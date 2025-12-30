# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Symbol < ActiveModel::Type::Value
    def serializable?(_)
      false
    end

    def cast_value(value)
      case value
      when Symbol, NilClass
        value
      else
        value.to_s.presence.try(:to_sym)
      end
    end
  end
end
