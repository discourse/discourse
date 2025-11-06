# frozen_string_literal: true

class LlmCreditAllocationSerializer < ApplicationSerializer
  attributes :id,
             :monthly_credits,
             :monthly_used,
             :credits_remaining,
             :percentage_used,
             :percentage_remaining,
             :next_reset_at,
             :soft_limit_percentage,
             :soft_limit_reached,
             :hard_limit_reached

  def soft_limit_reached
    object.soft_limit_reached?
  end

  def hard_limit_reached
    object.hard_limit_reached?
  end
end
