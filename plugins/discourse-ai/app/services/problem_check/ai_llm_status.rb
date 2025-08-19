# frozen_string_literal: true

class ProblemCheck::AiLlmStatus < ProblemCheck
  self.priority = "high"
  self.perform_every = 6.hours

  def call
    llm_errors
  end

  private

  def llm_errors
    return [] if !SiteSetting.discourse_ai_enabled
    LlmModel.in_use.find_each.filter_map do |model|
      try_validate(model) { validator.run_test(model) }
    end
  end

  def try_validate(model, &blk)
    begin
      blk.call
      nil
    rescue => e
      details = {
        model_id: model.id,
        model_name: model.display_name,
        error: parse_error_message(e.message),
        url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms/#{model.id}/edit",
      }

      message = I18n.t("dashboard.problem.ai_llm_status", details)

      Problem.new(
        message,
        priority: "high",
        identifier: "ai_llm_status",
        target: model.id,
        details:,
      )
    end
  end

  def validator
    @validator ||= DiscourseAi::Configuration::LlmValidator.new
  end

  def parse_error_message(message)
    begin
      JSON.parse(message)["message"]
    rescue JSON::ParserError
      message.to_s
    end
  end
end
