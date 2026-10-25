# frozen_string_literal: true

require "digest/sha2"
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
      max_bytes: MAX_BYTES,
    )
  end

  def initialize(data, validate: true, max_bytes: nil)
    raise ArgumentError unless data.is_a?(Hash)
    encoded = JSON.generate(data, max_nesting: 20)
    @bytesize = encoded.bytesize
    raise ArgumentError if max_bytes && @bytesize > max_bytes
    @data = JSON.parse(encoded, max_nesting: 20)
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
    self.class.new(@data.merge("answers" => answers), validate:, max_bytes: max_edit_bytes)
  end

  def max_edit_bytes
    [MAX_BYTES, @bytesize].max
  end

  def rewrite_text
    data = to_h
    data["definition"]["fields"].each do |field|
      label = field.dig("attributes", "label") || field["id"].to_s
      rewritten_label = yield(label)
      (field["attributes"] ||= {})["label"] = rewritten_label if rewritten_label != label

      next if field["type"] == "tag-chooser"

      id = field["id"].to_s
      value = data["answers"][id]
      if value.is_a?(String)
        data["answers"][id] = yield(value)
      elsif value.is_a?(Array)
        data["answers"][id] = value.map { |item| yield(item) }
      end
      if %w[dropdown multi-select].include?(field["type"])
        field["choices"]&.map! { |choice| choice.is_a?(String) ? yield(choice) : choice }
      end
    end

    if (output = data["definition"]["output_template"])
      # Expressions remain template logic, rather than editable post text.
      data["definition"]["output_template"] = output
        .split(/({{.*?}}|{%.*?%})/m)
        .map { |part| part.start_with?("{{", "{%") ? part : yield(part) }
        .join
    end

    self.class.new(data, validate: false)
  end

  def editor_data(raw:, guardian:)
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
    { template_id:, template: fields.to_yaml, answers:, state_token: state_token(raw:) }
  end

  def self.for_edit(post, payload:, guardian:, validate: true)
    guardian.ensure_can_edit!(post)
    submission = post.form_submission
    unless submission && payload.is_a?(String) && payload.bytesize <= submission.max_edit_bytes
      raise Discourse::InvalidParameters.new(:form_template_data)
    end
    data = JSON.parse(payload, max_nesting: 20)
    raise ArgumentError unless data.is_a?(Hash)
    submission.with_answers(data.fetch("answers"), validate:)
  rescue JSON::JSONError, ArgumentError, KeyError
    raise Discourse::InvalidParameters.new(:form_template_data)
  end

  def state_token(raw:)
    Digest::SHA256.hexdigest(canonical_value([raw, @data]).to_json)
  end

  private

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

  def canonical_value(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, canonical_value(value[key])] }
    when Array
      value.map { |item| canonical_value(item) }
    else
      value
    end
  end
end
