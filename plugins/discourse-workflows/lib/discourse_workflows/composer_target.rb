# frozen_string_literal: true

module DiscourseWorkflows
  # The composer a workflow started from, for nodes that show something in it.
  module ComposerTarget
    # Read from the trigger rather than the input items, which earlier nodes may have reshaped.
    def self.from(exec_ctx, item_index = 0)
      trigger_data = exec_ctx.get_context(:flow)&.fetch("$trigger", nil)
      trigger_data = trigger_data[item_index] || trigger_data.first if trigger_data.is_a?(Array)
      return if !trigger_data.is_a?(Hash)

      draft_key = trigger_data.dig("composer", "draft_key")
      return if !draft_key.is_a?(String) || draft_key.blank?

      session_id = trigger_data.dig("composer", "session_id")
      { draft_key:, session_id: session_id.is_a?(String) ? session_id : nil }
    end
  end
end
