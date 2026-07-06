# frozen_string_literal: true

class ReviewableAiToolActionSerializer < ReviewableSerializer
  target_attributes :tool_name, :tool_parameters, :post_id, :bot_user_id, :ai_agent_id
  payload_attributes :agent_name, :reason, :llm_model_id

  attributes :cooked, :revertible, :reverted

  def cooked
    post_id = object.target&.post_id
    Post.find_by(id: post_id)&.cooked if post_id
  end

  def reverted
    object.reverted?
  end

  def revertible
    object.approved? && object.revertible_tool? && !object.reverted?
  end
end
