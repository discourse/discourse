# frozen_string_literal: true

module AiCreditLimitHandler
  extend ActiveSupport::Concern

  included do
    rescue_from LlmCreditAllocation::CreditLimitExceeded do |e|
      render_credit_limit_error(e)
    end
  end

  private

  def render_credit_limit_error(exception)
    allocation = exception.allocation

    details = {}
    if allocation
      details[:reset_time_relative] = allocation.relative_reset_time
      details[:reset_time_absolute] = allocation.formatted_reset_time
    end

    user_type = current_user&.admin? ? "admin" : "user"
    reset_time = allocation&.relative_reset_time.presence || ""

    message =
      I18n.t(
        "discourse_ai.llm_credit_allocation.limit_exceeded_#{user_type}",
        reset_time: reset_time,
      )

    render json: {
             error: "credit_limit_exceeded",
             message: message,
             details: details,
           },
           status: :too_many_requests
  end
end
