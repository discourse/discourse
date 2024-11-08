# frozen_string_literal: true

class FormTemplateYamlValidator < ActiveModel::Validator
  RESERVED_KEYWORDS = %w[title body category category_id tags].freeze
  ALLOWED_TYPES = %w[checkbox dropdown input multi-select textarea upload].freeze
  HTML_SANITIZATION_OPTIONS = {
    elements: ["a"],
    attributes: {
      "a" => %w[href target],
    },
    protocols: {
      "a" => {
        "href" => %w[http https mailto],
      },
    },
  }.freeze

  def validate(record)
    begin
      yaml = Psych.safe_load(record.template)

      unless yaml.is_a?(Array)
        record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
        return
      end

      existing_ids = []
      yaml.each do |field|
        check_missing_fields(record, field)
        check_allowed_types(record, field)
        check_ids(record, field, existing_ids)
        check_descriptions_html(record, field)
      end
    rescue Psych::SyntaxError
      record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
    end
  end

  def check_allowed_types(record, field)
    if !ALLOWED_TYPES.include?(field["type"])
      record.errors.add(
        :template,
        I18n.t(
          "form_templates.errors.invalid_type",
          type: field["type"],
          valid_types: ALLOWED_TYPES.join(", "),
        ),
      )
    end
  end

  def check_missing_fields(record, field)
    if field["type"].blank?
      record.errors.add(:template, I18n.t("form_templates.errors.missing_type"))
    end
    record.errors.add(:template, I18n.t("form_templates.errors.missing_id")) if field["id"].blank?
  end

  def check_descriptions_html(record, field)
    description = field.dig("attributes", "description")

    return if description.blank?

    sanitized_html = Sanitize.fragment(description, HTML_SANITIZATION_OPTIONS)

    is_safe_html = sanitized_html == Loofah.html5_fragment(description).to_s

    unless is_safe_html
      record.errors.add(:template, I18n.t("form_templates.errors.unsafe_description"))
    end
  end

  def check_ids(record, field, existing_ids)
    if RESERVED_KEYWORDS.include?(field["id"])
      record.errors.add(:template, I18n.t("form_templates.errors.reserved_id", id: field["id"]))
    end

    if existing_ids.include?(field["id"])
      record.errors.add(:template, I18n.t("form_templates.errors.duplicate_ids"))
    end

    existing_ids << field["id"] if field["id"].present?
  end
end
