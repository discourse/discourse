# frozen_string_literal: true

module ActiveSupportTypeExtensions
  class Array < ActiveModel::Type::Value
    attr_reader :compact_blank, :element_type

    def initialize(compact_blank: false, element_type: nil)
      super()
      @compact_blank = compact_blank
      @element_type = element_type
      @element_caster = ->(value) { Integer(value, exception: false) || value }
      @scalar_caster = ->(value) { value }
      @element_caster = @scalar_caster = element_type.method(:cast).to_proc if element_type
    end

    def serializable?(_)
      false
    end

    def cast_value(value)
      case value
      when String
        cast_value(value.split(/,(?!.*\|)|\|(?!.*,)/))
      when ::Array
        value.map(&element_caster)
      else
        ::Array.wrap(value).map(&scalar_caster)
      end.tap { it.compact_blank! if compact_blank }
    end

    private

    attr_reader :element_caster, :scalar_caster
  end
end
