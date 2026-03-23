# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForHuman < StandardError
    attr_reader :type,
                :message_text,
                :approve_label,
                :deny_label,
                :channel_id,
                :timeout_minutes,
                :timeout_action,
                :form_fields,
                :form_title,
                :form_description

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
      form_description: nil
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
      super(
        (
          if type == :form
            "Workflow paused waiting for form submission"
          else
            "Workflow paused waiting for human approval"
          end
        ),
      )
    end

    def form?
      type == :form
    end

    def approval?
      type == :approval
    end
  end
end
