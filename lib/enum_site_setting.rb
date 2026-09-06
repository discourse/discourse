# frozen_string_literal: true

class EnumSiteSetting
  def self.translate_names?
    false
  end

  def self.wrap_values!
    value_class = Class.new(String)

    values.each do |entry|
      value = entry[:value].to_s
      value_class.define_method("#{value}?") { self == value }
    end

    const_set(:Value, value_class)
    define_singleton_method(:wrap) { |value| self::Value.new(value) }
  end
end
