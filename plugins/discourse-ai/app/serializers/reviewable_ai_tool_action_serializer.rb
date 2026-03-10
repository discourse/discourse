# frozen_string_literal: true

class ReviewableAiToolActionSerializer < ReviewableSerializer
  target_attributes :tool_name, :tool_parameters, :post_id, :bot_user_id, :ai_agent_id
  payload_attributes :agent_name, :reason, :llm_model_id, :post_cooked
end
