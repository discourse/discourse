# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForResume < StandardError
    attr_reader :type,
                :message_text,
                :approve_label,
                :deny_label,
                :channel_id,
                :timeout_minutes,
                :timeout_action,
                :form_fields,
                :form_title,
                :form_description,
                :wait_amount,
                :wait_unit,
                :http_method,
                :response_mode,
                :response_code

    def initialize(
      type: :approval,
      message_text: nil,
      channel_id: nil,
      approve_label: "Approve",
      deny_label: "Deny",
      timeout_minutes: nil,
      timeout_action: "deny",
      form_fields: nil,
      form_title: nil,
      form_description: nil,
      wait_amount: nil,
      wait_unit: nil,
      http_method: nil,
      response_mode: nil,
      response_code: nil
    )
      @type = type
      @message_text = message_text
      @approve_label = approve_label
      @deny_label = deny_label
      @channel_id = channel_id
      @timeout_minutes = timeout_minutes
      @timeout_action = timeout_action
      @form_fields = form_fields
      @form_title = form_title
      @form_description = form_description
      @wait_amount = wait_amount
      @wait_unit = wait_unit
      @http_method = http_method
      @response_mode = response_mode
      @response_code = response_code

      message =
        case type
        when :form
          "Workflow paused waiting for form submission"
        when :timer
          "Workflow paused waiting for timer (#{wait_amount} #{wait_unit})"
        when :webhook
          "Workflow paused waiting for webhook callback"
        else
          "Workflow paused waiting for human approval"
        end

      super(message)
    end

    def form?
      type == :form
    end

    def approval?
      type == :approval
    end

    def timer?
      type == :timer
    end

    def webhook?
      type == :webhook
    end
  end
end
