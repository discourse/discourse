# frozen_string_literal: true

class FormTemplate::FieldValues
  attr_reader :fields, :answers, :number_formats

  def initialize(fields:, answers:, number_formats: {})
    raise ArgumentError unless answers.is_a?(Hash) && number_formats.is_a?(Hash)

    @number_formats = number_formats.stringify_keys
    @fields = fields.map { |field| field.merge("id" => field.fetch("id").to_s) }
    @answers = answers.stringify_keys

    unknown_ids = @answers.keys - @fields.map { |field| field.fetch("id") }
    raise ArgumentError, "Unknown field IDs: #{unknown_ids.join(", ")}" if unknown_ids.any?

    @number_formats.each do |id, text|
      field = @fields.find { |candidate| candidate["id"] == id }
      unless field && field["type"] == "input" && field.dig("validations", "type") == "number" &&
               text.is_a?(String)
        raise ArgumentError
      end
      if text.empty?
        raise ArgumentError unless @answers[id].nil?
      else
        unless /\A-?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\z/.match?(text) &&
                 Float(text).finite? && Float(text) == @answers[id]
          raise ArgumentError
        end
      end
    end

    @fields.each do |field|
      id = field.fetch("id")
      next if !@answers.key?(id) || @answers[id].nil?

      raise ArgumentError, "Invalid value for field: #{id}" unless valid_value?(field, @answers[id])
    end
  end

  # HTML constraints remain browser-side; Ruby regexes, lengths, and choice strings differ.
  def validate!
    @fields.each do |field|
      value = answers[field.fetch("id")]
      next if field.dig("attributes", "disabled")

      rules = field["validations"] || {}
      invalid = rules["required"] && (value.nil? || value == false || value == "" || value == [])
      if invalid
        raise FormTemplate::InvalidAnswers,
              I18n.t(
                "form_templates.invalid_answer",
                field: field.dig("attributes", "label") || field["id"],
              )
      end
    end
  end

  private

  def valid_value?(field, value)
    case field.fetch("type")
    when "checkbox"
      value == true || value == false
    when "multi-select"
      string_array?(value)
    when "tag-chooser"
      field.dig("attributes", "multiple") ? string_array?(value) : value.is_a?(String)
    when "input"
      if field.dig("validations", "type") == "number"
        value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
      else
        value.is_a?(String)
      end
    when "dropdown", "textarea", "upload", "composer"
      value.is_a?(String)
    else
      false
    end
  end

  def string_array?(value)
    value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
  end
end
