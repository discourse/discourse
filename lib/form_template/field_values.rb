# frozen_string_literal: true

class FormTemplate::FieldValues
  MAX_NUMBER_LENGTH = 1024
  NUMBER_PATTERN = /\A-?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\z/

  attr_reader :fields, :answers

  def initialize(fields:, answers:)
    @fields = fields.map { |field| field.merge("id" => field.fetch("id").to_s) }
    @answers = answers.stringify_keys
  end

  def well_formed?
    unknown_ids.empty? && fields.all? { |field| acceptable?(field, answers[field["id"]]) }
  end

  # Output templates compare and calculate with number answers, which only
  # works once they are numeric.
  def template_answers
    fields.each_with_object(answers.dup) do |field, typed|
      value = typed[field["id"]]
      typed[field["id"]] = to_number(value) if number_field?(field) && value.is_a?(String)
    end
  end

  # HTML constraints remain browser-side; Ruby regexes, lengths, and choice strings differ.
  def incomplete_fields
    fields.select { |field| required?(field) && blank_answer?(answers[field["id"]]) }
  end

  private

  def unknown_ids
    answers.keys - fields.map { |field| field["id"] }
  end

  def required?(field)
    field.dig("validations", "required") && !field.dig("attributes", "disabled")
  end

  def blank_answer?(value)
    value.nil? || value == false || value == "" || value == []
  end

  def acceptable?(field, value)
    return true if value.nil?

    case field["type"]
    when "checkbox"
      value == true || value == false
    when "multi-select"
      string_array?(value)
    when "tag-chooser"
      field.dig("attributes", "multiple") ? string_array?(value) : value.is_a?(String)
    when "input"
      number_field?(field) ? number?(value) : value.is_a?(String)
    when "dropdown", "textarea", "upload", "composer"
      value.is_a?(String)
    else
      false
    end
  end

  def number_field?(field)
    field["type"] == "input" && field.dig("validations", "type") == "number"
  end

  def to_number(value)
    return if value.empty?
    value.match?(/\A-?[0-9]+\z/) ? Integer(value, 10) : BigDecimal(value)
  end

  # Numbers keep the spelling typed into the control, so a round trip through
  # JSON cannot alter them and the control can be repopulated verbatim.
  def number?(value)
    return false unless value.is_a?(String) && value.bytesize <= MAX_NUMBER_LENGTH

    value.empty? || (NUMBER_PATTERN.match?(value) && Float(value, exception: false)&.finite?)
  end

  def string_array?(value)
    value.is_a?(Array) && value.all?(String)
  end
end
