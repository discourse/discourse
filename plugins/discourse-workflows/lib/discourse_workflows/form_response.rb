# frozen_string_literal: true

module DiscourseWorkflows
  module FormResponse
    WORKFLOW_FINISHES_RESPONSE_MODE = "workflow_finishes"

    module_function

    def initial_submission(execution, response_metadata)
      response_mode = response_metadata[:response_mode]
      payload = {
        has_downstream_form: response_metadata[:has_downstream_form],
        response_mode: response_mode,
        status: execution&.status,
      }

      if DiscourseWorkflows::WaitingWebhookRunner.waiting_for?(execution, node_type: "form")
        payload.merge!(DiscourseWorkflows::WaitingExecution.form_urls(execution))
      elsif execution&.success?
        form_completion = DiscourseWorkflows::FormCompletion.from_execution(execution)
        return if no_data_response?(execution, response_mode, form_completion)

        payload[:form_completion] = form_completion
      elsif execution&.error?
        payload[:errors] = [workflow_error_message]
      elsif no_data_response?(execution, response_mode)
        return
      end

      payload.compact
    end

    def initial_submission_status(execution, response_metadata)
      if response_metadata[:response_mode] == WORKFLOW_FINISHES_RESPONSE_MODE && execution&.error?
        return :internal_server_error
      end

      :ok
    end

    def resumed_submission(execution)
      response_mode = trigger_response_mode(execution)
      body = { status: execution.status }

      if DiscourseWorkflows::WaitingWebhookRunner.waiting_for?(execution, node_type: "form")
        body.merge!(DiscourseWorkflows::WaitingExecution.form_urls(execution))
      elsif execution.success?
        form_completion = DiscourseWorkflows::FormCompletion.from_execution(execution)
        return if no_data_response?(execution, response_mode, form_completion)

        body[:form_completion] = form_completion
      elsif execution.error?
        body[:errors] = [workflow_error_message]
      elsif no_data_response?(execution, response_mode)
        return
      end

      body.compact
    end

    def resumed_submission_status(execution)
      return :internal_server_error if execution.error?

      :ok
    end

    def workflow_error_message
      I18n.t("discourse_workflows.errors.workflow_failed")
    end

    def no_data_response?(execution, response_mode, form_completion = nil)
      return false unless response_mode == WORKFLOW_FINISHES_RESPONSE_MODE
      if DiscourseWorkflows::WaitingWebhookRunner.waiting_for?(execution, node_type: "form")
        return false
      end

      execution&.waiting? || (execution&.success? && form_completion.blank?)
    end

    def trigger_response_mode(execution)
      return if execution.blank?

      trigger_node = execution.workflow_node(execution.trigger_node_id)
      return if trigger_node.blank?

      DiscourseWorkflows::NodeData.parameters(trigger_node)["response_mode"]
    end
  end
end
