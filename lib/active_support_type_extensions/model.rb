# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Model < ActiveModel::Type::Value
    attr_reader :class_name

    def initialize(class_name:, **kwargs)
      super(**kwargs)
      @class_name = class_name
    end

    def serializable?(_)
      false
    end

    def cast_value(value)
      case value
      when class_name
        value
      when Integer, String
        class_name.find_by(id: value)
      else
        value
      end
    end

    def type
      :model
    end
  end
end
