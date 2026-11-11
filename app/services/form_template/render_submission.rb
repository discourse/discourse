# frozen_string_literal: true

class FormTemplate::RenderSubmission
  include Service::Base

  MAX_PAYLOAD_SIZE = 1.megabyte

  params do
    attribute :category_id, :integer
    attribute :form_template_data, :string
    attribute :submission, :hash do
      attribute :id, :integer
      attribute :answers

      validates :id, presence: true
      validate { errors.add(:answers, :invalid) unless answers.is_a?(Hash) }
    end

    validates :category_id, :form_template_data, :submission, presence: true

    validate do
      if form_template_data.to_s.bytesize > MAX_PAYLOAD_SIZE
        errors.add(:form_template_data, :too_long)
      end
    end

    before_validation { self.submission = parsed_form_template_data }

    private

    def parsed_form_template_data
      return if form_template_data.to_s.bytesize > MAX_PAYLOAD_SIZE
      JSON.parse(form_template_data.to_s)
    rescue JSON::ParserError
      nil
    end
  end

  options { attribute :allow_incomplete_answers, :boolean, default: false }

  policy :form_templates_enabled
  model :category
  policy :can_create_topic_on_category
  model :form_template
  model :field_values, :build_field_values
  policy :answers_match_fields
  only_if(:answers_must_be_complete) do
    policy :answers_are_complete, class_name: FormTemplate::Policy::AnswersAreComplete
  end
  try(Liquid::Error) { step :render }

  private

  def form_templates_enabled
    SiteSetting.enable_form_templates
  end

  def fetch_category(params:)
    Category.find_by(id: params.category_id)
  end

  def can_create_topic_on_category(guardian:, category:)
    guardian.can_create_topic_on_category?(category)
  end

  def fetch_form_template(params:, category:)
    category.form_templates.find_by(id: params.submission.id)
  end

  def build_field_values(params:, form_template:)
    FormTemplate::FieldValues.new(fields: form_template.fields, answers: params.submission.answers)
  end

  def answers_match_fields(field_values:)
    field_values.well_formed?
  end

  def answers_must_be_complete(options:)
    !options.allow_incomplete_answers
  end

  def render(field_values:, form_template:)
    context[:raw] = FormTemplate::OutputRenderer.render(field_values, form_template.output_template)
  end
end
