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

    render json: {
             error: "credit_limit_exceeded",
             message: exception.message,
             details: details,
           },
           status: :too_many_requests
  end
end
