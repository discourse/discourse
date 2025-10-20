# frozen_string_literal: true

class ProblemCheck::AiCreditSoftLimit < ProblemCheck
  self.priority = "low"
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
        allocation.reset_if_needed!

        if allocation.soft_limit_reached? && !allocation.hard_limit_reached?
          problems << soft_limit_problem(model, allocation)
        end
      end

    problems.compact
  end

  private

  def targets
    LlmModel.joins(:llm_credit_allocation).where("llm_models.id < 0").pluck("llm_models.id")
  end

  def soft_limit_problem(model, allocation)
    override_data = {
      model_id: model.id,
      model_name: model.display_name,
      percentage_remaining: allocation.percentage_remaining.round,
      reset_date: format_reset_date(allocation.next_reset_at),
      url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms",
    }

    problem(model, override_data:)
  end

  def format_reset_date(date)
    I18n.l(date, format: :long)
  end
end
