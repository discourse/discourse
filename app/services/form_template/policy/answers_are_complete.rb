# frozen_string_literal: true

class FormTemplate::Policy::AnswersAreComplete < Service::PolicyBase
  delegate :field_values, to: :context, private: true

  def call
    incomplete_field.nil?
  end

  def reason
    I18n.t(
      "form_templates.invalid_answer",
      field: incomplete_field.dig("attributes", "label") || incomplete_field["id"],
    )
  end

  private

  def incomplete_field
    field_values.incomplete_fields.first
  end
end
