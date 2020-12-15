# frozen_string_literal: true

class DoNotDisturbTiming < ActiveRecord::Base
  belongs_to :user

  validate :ends_at_greater_thans_starts_at

  def ends_at_greater_thans_starts_at
    if starts_at > ends_at
      errors.add(:ends_at, :invalid)
    end
  end
end
