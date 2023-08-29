# frozen_string_literal: true

class FormTemplateYamlValidator < ActiveModel::Validator
  RESERVED_KEYWORDS = %w[title body category category_id tags]
  ALLOWED_TYPES = %w[checkbox dropdown input multi-select textarea upload]

  def validate(record)
    begin
      yaml = Psych.safe_load(record.template)
      check_missing_fields(record, yaml)
      check_allowed_types(record, yaml)
      check_ids(record, yaml)
    rescue Psych::SyntaxError
      record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
    end
  end

  def check_allowed_types(record, yaml)
    yaml.each do |field|
      if !ALLOWED_TYPES.include?(field["type"])
        return(
          record.errors.add(
            :template,
            I18n.t(
              "form_templates.errors.invalid_type",
              type: field["type"],
              valid_types: ALLOWED_TYPES.join(", "),
            ),
          )
        )
      end
    end
  end

  def check_missing_fields(record, yaml)
    yaml.each do |field|
      if field["type"].blank?
        return(record.errors.add(:template, I18n.t("form_templates.errors.missing_type")))
      end
      if field["id"].blank?
        return(record.errors.add(:template, I18n.t("form_templates.errors.missing_id")))
      end
    end
  end

  def check_ids(record, yaml)
    ids = []
    yaml.each do |field|
      next if field["id"].blank?

      if RESERVED_KEYWORDS.include?(field["id"])
        return(
          record.errors.add(:template, I18n.t("form_templates.errors.reserved_id", id: field["id"]))
        )
      end

      if ids.include?(field["id"])
        return(record.errors.add(:template, I18n.t("form_templates.errors.duplicate_ids")))
      end

      ids << field["id"]
    end
  end
end
