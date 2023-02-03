# frozen_string_literal: true

class FormTemplateYamlValidator < ActiveModel::Validator
  def validate(record)
    begin
      yaml = Psych.safe_load(record.template)
    rescue Psych::SyntaxError
      record.errors.add(:template, I18n.t("form_templates.errors.invalid_yaml"))
    end
  end
end
