# frozen_string_literal: true

class ProblemCheck::AiLlmStatus < ProblemCheck
  self.priority = "high"
  self.perform_every = 6.hours
  self.max_retries = 2
  self.retry_after = 1.minute
  self.max_blips = 2
  self.targets = -> { LlmModel.in_use.pluck(:id) }

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled

    model = LlmModel.in_use.find_by(id: target)

    return no_problem if model.blank?
    return no_problem if model.seeded?

    try_validate(model) { validator.run_test(model) }
  end

  private

  def try_validate(model, &blk)
    begin
      blk.call
      no_problem
    rescue => e
      # Skip problem reporting for rate limiting and temporary service issues
      # These are expected to resolve on their own
      if rate_limit_error?(e)
        Rails.logger.info(
          "AI LLM Status Check: Rate limit detected for model #{model.display_name} (#{model.id}), skipping problem report",
        )
        return no_problem
      end

      # Log transient errors but still return a problem
      # The framework's max_retries and max_blips will handle retries and alert suppression
      if transient_error?(e)
        Rails.logger.info(
          "AI LLM Status Check: Transient error for model #{model.display_name} (#{model.id}): #{e.message}",
        )
      end

      override_data = {
        model_id: model.id,
        model_name: model.display_name,
        url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms/#{model.id}/edit",
      }

      problem(model, override_data:, details: { error: parse_error_message(e.message) })
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

  def rate_limit_error?(error)
    error_message = error.message.to_s.downcase

    # Check for rate limit indicators in the error message
    rate_limit_indicators = [
      "rate limit",
      "rate_limit",
      "ratelimit",
      "too many requests",
      "quota exceeded",
      "retry after",
      "throttled",
      "429",
      "503",
      "temporarily unavailable",
      "service unavailable",
      "overloaded",
    ]

    rate_limit_indicators.any? { |indicator| error_message.include?(indicator) }
  end

  def transient_error?(error)
    # Network errors and timeouts are transient - may succeed on retry
    transient_errors = [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      IOError,
    ]

    transient_errors.any? { |error_class| error.is_a?(error_class) }
  end
end
