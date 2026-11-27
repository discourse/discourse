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
        cast_value(split_string(value))
      when ::Array
        value.map(&element_caster)
      else
        ::Array.wrap(value).map(&scalar_caster)
      end.tap { it.compact_blank! if compact_blank }
    end

    private

    attr_reader :element_caster, :scalar_caster

    # Only the separator coming last in `value` splits it, so occurrences of
    # the other one are kept. Using `rindex` keeps this linear, unlike a regexp
    # that looks ahead at every separator.
    def split_string(value)
      last_comma = value.rindex(",")
      last_pipe = value.rindex("|")

      if last_pipe.nil? || (last_comma && last_comma > last_pipe)
        separator, split_from = ",", last_pipe
      else
        separator, split_from = "|", last_comma
      end

      prefix = split_from ? value[0..split_from] : ""
      parts = value[(split_from ? split_from + 1 : 0)..].split(separator)

      prefix.empty? ? parts : [prefix + parts.first.to_s, *parts.drop(1)]
    end
  end
end
