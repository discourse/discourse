# frozen_string_literal: true

module FormTemplateSubmissions
  private

  def render_form_submission(category_id:, **options)
    FormTemplate::RenderSubmission.call(
      service_params.deep_merge(params: { category_id: }, options:),
    ) do
      on_success { |raw:| yield raw }
      on_failed_contract do |contract|
        raise Discourse::InvalidParameters.new(contract.errors.attribute_names.first)
      end
      on_failed_policy(:form_templates_enabled) { raise Discourse::InvalidAccess }
      on_model_not_found(:category) { raise Discourse::InvalidAccess }
      on_failed_policy(:can_create_topic_on_category) { raise Discourse::InvalidAccess }
      on_model_not_found(:form_template) { raise Discourse::NotFound }
      on_failed_policy(:answers_match_fields) do
        raise Discourse::InvalidParameters.new(:form_template_data)
      end
      on_failed_policy(:answers_are_complete) do |policy|
        render_json_error(policy.reason, status: :unprocessable_entity)
      end
      on_exceptions(Liquid::Error) do |exception, form_template: nil|
        # Previews render on every pause in typing, so only failed submissions are worth logging.
        if !options[:allow_incomplete_answers]
          Discourse.warn_exception(
            exception,
            message: "Form template output failed to render",
            env: {
              category_id:,
              form_template_id: form_template&.id,
            },
          )
        end
        render_json_error(
          I18n.t("form_templates.output_unavailable"),
          status: :unprocessable_entity,
        )
      end
    end
  end
end
