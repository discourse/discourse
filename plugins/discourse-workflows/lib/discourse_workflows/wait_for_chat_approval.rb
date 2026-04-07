# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForChatApproval < WaitForResume
    attr_reader :message_text, :approve_label, :deny_label, :channel_id, :timeout_minutes,
                :timeout_action

    def initialize(
      message_text:,
      channel_id:,
      approve_label: "Approve",
      deny_label: "Deny",
      timeout_minutes: nil,
      timeout_action: "deny"
    )
      @message_text = message_text
      @approve_label = approve_label
      @deny_label = deny_label
      @channel_id = channel_id
      @timeout_minutes = timeout_minutes
      @timeout_action = timeout_action
      super(type: :chat_approval, message: "Workflow paused waiting for chat approval")
    end
  end
end
