# frozen_string_literal: true

class ProblemCheck::AiCreditHardLimit < ProblemCheck
  self.priority = "high"
  self.perform_every = 1.hour

  def call
    return [] if !SiteSetting.discourse_ai_enabled

    problems = []

    LlmModel
      .where("id < 0")
      .includes(:llm_credit_allocation)
      .find_each do |model|
        next unless model.llm_credit_allocation

        allocation = model.llm_credit_allocation

        problems << hard_limit_problem(model, allocation) if allocation.hard_limit_reached?
      end

    problems.compact
  end

  private

  def targets
    LlmModel.joins(:llm_credit_allocation).where("llm_models.id < 0").pluck("llm_models.id")
  end

  def hard_limit_problem(model, allocation)
    override_data = {
      model_id: model.id,
      model_name: model.display_name,
      reset_date: format_reset_date(allocation.next_reset_at),
      url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms",
    }

    problem(model, override_data:)
  end

  def format_reset_date(date)
    I18n.l(date, format: :long)
  end
end
