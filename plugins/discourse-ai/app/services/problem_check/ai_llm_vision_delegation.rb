# frozen_string_literal: true

class ProblemCheck::AiLlmVisionDelegation < ProblemCheck
  self.perform_every = 6.hours
  self.priority = "high"
  self.targets = -> { LlmModel.where.not(vision_llm_model_id: nil).pluck(:id) }

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled

    model = LlmModel.find_by(id: target)
    return no_problem if model.blank? || model.delegated_vision?

    reason =
      if model.vision_enabled?
        :native_and_delegated
      elsif model.vision_llm_model_id == model.id
        :self_reference
      elsif model.vision_llm_model.blank?
        :missing
      elsif model.vision_llm_model.vision_llm_model_id.present?
        :delegated
      else
        :not_native
      end

    problem(
      model,
      override_data: {
        model_name: model.display_name,
        reason: I18n.t("dashboard.problem.ai_llm_vision_delegation_reasons.#{reason}"),
        url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms/#{model.id}/edit",
      },
      details: {
        model_id: model.id,
        vision_llm_model_id: model.vision_llm_model_id,
        reason: reason.to_s,
      },
    )
  end
end
