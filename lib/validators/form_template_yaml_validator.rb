# frozen_string_literal: true

class FormTemplateYamlValidator < ActiveModel::Validator
  RESERVED_KEYWORDS = %w[title body category category_id tags]
  ALLOWED_TYPES = %w[checkbox dropdown input multi-select textarea upload tag-chooser composer]
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
  }

  def validate(record)
    yaml = Psych.safe_load(record.template)

    unless yaml.is_a?(Array)
      record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
      return
    end

    existing_ids = []
    yaml.each do |field|
      if !field.is_a?(Hash)
        record.errors.add(:template, I18n.t("form_templates.errors.invalid_field"))
        next
      end
      check_field_options(record, field)
      check_missing_fields(record, field)
      check_allowed_types(record, field)
      check_ids(record, field, existing_ids)
      check_descriptions_html(record, field)
    end

    check_tag_groups(record, yaml.filter_map { |f| f["tag_group"] if f.is_a?(Hash) })
  rescue Psych::SyntaxError
    record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
  end

  def check_field_options(record, field)
    return if %w[attributes validations].all? { |key| field[key].nil? || field[key].is_a?(Hash) }
    record.errors.add(:template, I18n.t("form_templates.errors.invalid_field_options"))
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
    return if !field["attributes"].is_a?(Hash)
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

    # Answers are keyed by the id as a string, so `1` and `'1'` collide.
    if existing_ids.include?(field["id"].to_s)
      record.errors.add(:template, I18n.t("form_templates.errors.duplicate_ids"))
    end

    existing_ids << field["id"].to_s if field["id"].present?
  end

  def check_tag_groups(record, tag_group_names)
    tag_group_names = tag_group_names.compact.map(&:downcase).uniq
    valid_tag_group_names =
      TagGroup.where("lower(name) IN (?)", tag_group_names).pluck(:name).map(&:downcase)
    invalid_tag_groups = tag_group_names - valid_tag_group_names
    invalid_tag_groups.each do |tag_group_name|
      record.errors.add(
        :template,
        I18n.t("form_templates.errors.invalid_tag_group", tag_group_name: tag_group_name),
      )
    end
  end
end
