# frozen_string_literal: true

require "liquid"

class FormTemplate::Submission
  FORMAT_VERSION = 1
  MAX_BYTES = 64.kilobytes
  KEYS = %w[format_version template_id definition answers].freeze

  def self.from_template(template, answers:, validate: true)
    new(
      {
        "format_version" => FORMAT_VERSION,
        "template_id" => template.id,
        "definition" => {
          "fields" => template.fields,
          "output_template" => template.output_template,
        },
        "answers" => answers,
      },
      validate:,
    )
  end

  def self.for_edit(post, payload:, guardian:, validate: true)
    guardian.ensure_can_edit!(post)
    submission = post.form_submission
    unless submission && payload.is_a?(String) && payload.bytesize <= MAX_BYTES
      raise Discourse::InvalidParameters.new(:form_template_data)
    end
    data = JSON.parse(payload, max_nesting: 20)
    raise ArgumentError unless data.is_a?(Hash)
    submission.with_answers(data.fetch("answers"), validate:)
  rescue JSON::JSONError, ArgumentError, KeyError
    raise Discourse::InvalidParameters.new(:form_template_data)
  end

  def initialize(data, validate: true)
    raise ArgumentError unless data.is_a?(Hash)
    encoded = JSON.generate(data, max_nesting: 20)
    raise ArgumentError if encoded.bytesize > MAX_BYTES
    @data = JSON.parse(encoded, max_nesting: 20)
    # JSONB cannot store NUL, including in answers omitted from the rendered post.
    raise ArgumentError if contains_nul?(@data)
    unless @data.keys.sort == KEYS.sort && @data["format_version"] == FORMAT_VERSION &&
             @data["template_id"].is_a?(Integer) && @data["template_id"].positive?
      raise ArgumentError
    end

    raise ArgumentError unless @data["answers"].is_a?(Hash)
    definition = @data["definition"]
    raise ArgumentError unless valid_definition?(definition)

    @values = FormTemplate::FieldValues.new(fields: definition["fields"], answers: @data["answers"])
    raise ArgumentError unless @values.well_formed?
    if validate && (field = @values.incomplete_fields.first)
      raise FormTemplate::InvalidAnswers,
            I18n.t(
              "form_templates.invalid_answer",
              field: field.dig("attributes", "label") || field["id"],
            )
    end
    Liquid::Template.parse(definition["output_template"]) if definition["output_template"].present?
  rescue JSON::JSONError
    raise ArgumentError
  rescue Liquid::Error
    raise FormTemplate::InvalidAnswers, I18n.t("form_templates.errors.invalid_output_template")
  end

  def to_h
    @data.deep_dup
  end

  def answers
    @data["answers"].deep_dup
  end

  def answers_match?(payload)
    payload.is_a?(String) && payload.bytesize <= MAX_BYTES &&
      JSON.parse(payload, max_nesting: 20) == @data["answers"]
  rescue JSON::JSONError
    false
  end

  def template_id
    @data["template_id"]
  end

  def render
    FormTemplate::OutputRenderer.render(@values, @data["definition"]["output_template"])
  rescue Liquid::Error
    raise FormTemplate::InvalidAnswers, I18n.t("form_templates.output_unavailable")
  end

  def normalized_raw
    TextCleaner.normalize_whitespaces(render).rstrip
  end

  def with_answers(answers, validate: true)
    self.class.new(@data.merge("answers" => answers), validate:)
  end

  def rewrite_answers
    data = to_h
    data["answers"].transform_values! do |value|
      case value
      when String
        yield(value)
      when Array
        value.map { |item| item.is_a?(String) ? yield(item) : item }
      else
        value
      end
    end
    self.class.new(data, validate: false)
  end

  def editor_data(guardian:)
    fields = @data["definition"]["fields"].deep_dup
    tag_fields = fields.select { |field| field["type"] == "tag-chooser" }
    if tag_fields.present?
      ids = tag_fields.flat_map { |field| Array(field["choices"]).pluck("id") }
      visible_ids = DiscourseTagging.filter_visible(Tag.where(id: ids), guardian).pluck(:id).to_set
      tag_fields.each do |field|
        field["choices"] = Array(field["choices"]).select do |choice|
          visible_ids.include?(choice["id"])
        end
        if field.dig("attributes", "tag_choices")
          field["attributes"]["tag_choices"].slice!(*field["choices"].pluck("name"))
        end
      end
    end
    { template_id:, template: fields.to_yaml, answers: }
  end

  private

  def contains_nul?(value)
    case value
    when String
      value.include?("\u0000")
    when Hash
      value.any? { |key, item| contains_nul?(key) || contains_nul?(item) }
    when Array
      value.any? { |item| contains_nul?(item) }
    end
  end

  def valid_definition?(definition)
    return false unless definition.is_a?(Hash) && definition.keys.sort == %w[fields output_template]
    output = definition["output_template"]
    return false if !output.nil? && !output.is_a?(String)

    fields = definition["fields"]
    return false unless fields.is_a?(Array)
    return false unless fields.all? { |field| valid_field?(field) }

    fields.map { |field| field["id"].to_s }.uniq.size == fields.size
  end

  def valid_field?(field)
    field.is_a?(Hash) && (field["id"].is_a?(String) || field["id"].is_a?(Numeric)) &&
      field["id"].to_s.present? &&
      FormTemplateYamlValidator::ALLOWED_TYPES.include?(field["type"]) &&
      %w[attributes validations].all? { |key| field[key].nil? || field[key].is_a?(Hash) } &&
      (field["choices"].nil? || field["choices"].is_a?(Array))
  end
end
