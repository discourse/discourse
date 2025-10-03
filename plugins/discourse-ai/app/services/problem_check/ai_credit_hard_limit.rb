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
        allocation.reset_if_needed!

        problems << hard_limit_problem(model, allocation) if allocation.hard_limit_reached?
      end

    problems.compact
  end

  private

  def hard_limit_problem(model, allocation)
    details = {
      model_id: model.id,
      model_name: model.display_name,
      reset_date: format_reset_date(allocation.next_reset_at),
      url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms",
    }

    message = I18n.t("dashboard.problem.ai_credit_hard_limit", details)

    Problem.new(
      message,
      priority: "high",
      identifier: "ai_credit_hard_limit",
      target: model.id,
      details:,
    )
  end

  def format_reset_date(date)
    I18n.l(date, format: :long)
  end
end
