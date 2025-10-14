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

  def soft_limit_problem(model, allocation)
    details = {
      model_id: model.id,
      model_name: model.display_name,
      percentage_remaining: allocation.percentage_remaining.round,
      reset_date: format_reset_date(allocation.next_reset_at),
      url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms",
    }

    message = I18n.t("dashboard.problem.ai_credit_soft_limit", details)

    Problem.new(
      message,
      priority: "low",
      identifier: "ai_credit_soft_limit",
      target: model.id,
      details:,
    )
  end

  def format_reset_date(date)
    I18n.l(date, format: :long)
  end
end
