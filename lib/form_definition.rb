# frozen_string_literal: true

class FormDefinition
  TYPES = %w[text textarea number date checkbox dropdown radio].freeze
  CHOICES = %w[dropdown radio].freeze
  PLACEHOLDERS = %w[text textarea number].freeze
  RESERVED_KEYS = %w[
    constructor
    prototype
    toString
    valueOf
    hasOwnProperty
    isPrototypeOf
    propertyIsEnumerable
    toLocaleString
  ].freeze
  KEY = /\A[a-z][a-zA-Z0-9_]{0,63}\z/

  def initialize(definition)
    @definition = definition
  end

  def valid?
    return false unless @definition.is_a?(Hash) && text?(@definition["title"], 255)
    return false unless optional_text?(@definition["description"], 2000)

    fields = @definition["fields"]
    keyed_list?(fields) && fields.all? { |field| valid_field?(field) }
  end

  def invalid_answers(answers)
    @definition
      .fetch("fields")
      .reject do |field|
        value = answers[field.fetch("id")]
        if value.nil? || value == "" || (value.is_a?(String) && value.blank?)
          !field["required"]
        else
          valid_value?(field, value)
        end
      end
  end

  private

  def valid_field?(field)
    type = field["type"]
    return false unless TYPES.include?(type) && text?(field["label"], 255)
    return false if [true, false].exclude?(field["required"])
    if field.key?("placeholder") &&
         !(PLACEHOLDERS.include?(type) && optional_text?(field["placeholder"], 255))
      return false
    end
    return !field.key?("choices") if CHOICES.exclude?(type)

    choices = field["choices"]
    keyed_list?(choices) && choices.any? && choices.all? { |choice| text?(choice["label"], 255) }
  end

  def keyed_list?(items)
    return false unless items.is_a?(Array) && items.size <= 100
    unless items.all? { |item|
             item.is_a?(Hash) && item["id"].is_a?(String) && KEY.match?(item["id"]) &&
               RESERVED_KEYS.exclude?(item["id"])
           }
      return false
    end
    items.pluck("id").uniq.size == items.size
  end

  def text?(value, max)
    value.is_a?(String) && value.present? && value.size <= max
  end

  def optional_text?(value, max)
    value.nil? || (value.is_a?(String) && value.size <= max)
  end

  def valid_value?(field, value)
    case field["type"]
    when "text", "textarea"
      text?(value, 10_000)
    when "number"
      (value.is_a?(Numeric) || value.is_a?(String)) && Float(value, exception: false)&.finite?
    when "date"
      value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value) && Date.iso8601(value)
    when "checkbox"
      value == true || (!field["required"] && value == false)
    when *CHOICES
      field["choices"].any? { |choice| choice["id"] == value }
    end
  rescue Date::Error
    false
  end
end
