# frozen_string_literal: true

class ProblemCheck::AiImageCaptionAgent < ProblemCheck
  self.priority = "high"

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled
    return no_problem if !SiteSetting.ai_post_image_captions_enabled

    agent_id = SiteSetting.ai_image_caption_agent.to_i
    agent = AiAgent.find_by(id: agent_id)
    return agent_problem(:agent_missing, agent_id: agent_id) if agent.blank?

    agent_class = agent.class_instance
    return agent_problem(:agent_vision_disabled, agent_id: agent_id) if !agent_class&.vision_enabled

    llm_model = DiscourseAi::PostImageCaptions.image_caption_llm_model(agent)
    return agent_problem(:llm_missing, agent_id: agent_id) if llm_model.blank?
    return agent_problem(:llm_vision_disabled, agent_id: agent_id) if !llm_model.vision_enabled?

    no_problem
  end

  private

  def agent_problem(reason_key, agent_id:)
    problem(
      agent_id,
      override_data: {
        reason: I18n.t("dashboard.problem.ai_image_caption_agent_reasons.#{reason_key}"),
        url: url(agent_id),
      },
      details: {
        agent_id: agent_id,
        reason: reason_key.to_s,
      },
    )
  end

  def url(agent_id)
    if AiAgent.exists?(id: agent_id)
      "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-agents/#{agent_id}/edit"
    else
      "#{Discourse.base_path}/admin/plugins/discourse-ai/settings?filter=ai_image_caption_agent"
    end
  end
end
