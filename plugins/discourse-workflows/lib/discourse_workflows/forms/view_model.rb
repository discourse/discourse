# frozen_string_literal: true

module DiscourseWorkflows
  module Forms
    module ViewModel
      module_function

      def build(
        fields:,
        form_title:,
        form_description:,
        response_mode:,
        has_downstream_form:,
        form_submit_url: nil,
        form_waiting_url: nil,
        form_status_url: nil,
        form_channel: nil,
        resume_token: nil,
        form_mode: nil
      )
        schema = DiscourseWorkflows::Forms::Schema.build(fields)

        {
          form_title: form_title,
          form_description: form_description,
          data: schema[:data],
          fields: schema[:fields],
          response_mode: response_mode,
          has_downstream_form: has_downstream_form,
          form_submit_url: form_submit_url,
          form_waiting_url: form_waiting_url,
          form_status_url: form_status_url,
          form_channel: form_channel,
          resume_token: resume_token,
          form_mode: form_mode,
        }.compact
      end
    end
  end
end
