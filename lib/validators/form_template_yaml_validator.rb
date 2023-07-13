# frozen_string_literal: true

class FormTemplateYamlValidator < ActiveModel::Validator
  def validate(record)
    begin
      yaml = Psych.safe_load(record.template)
      check_missing_type(record, yaml)
      check_allowed_types(record, yaml)
    rescue Psych::SyntaxError
      record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
    end
  end

  def check_allowed_types(record, yaml)
    allowed_types = %w[checkbox dropdown input multi-select textarea upload]
    yaml.each do |field|
      if !allowed_types.include?(field["type"])
        return(
          record.errors.add(
            :template,
            I18n.t(
              "form_templates.errors.invalid_type",
              type: field["type"],
              valid_types: allowed_types.join(", "),
            ),
          )
        )
      end
    end
  end

  def check_missing_type(record, yaml)
    yaml.each do |field|
      if field["type"].blank?
        return record.errors.add(:template, I18n.t("form_templates.errors.missing_type"))
      end
    end
  end
end
