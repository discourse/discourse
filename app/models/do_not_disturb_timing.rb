# frozen_string_literal: true

class DoNotDisturbTiming < ActiveRecord::Base
  belongs_to :user

  validate :ends_at_greater_thans_starts_at

  after_commit :publish_if_active, on: [:create, :update]

  private

  def publish_if_active
    user.publish_do_not_disturb
  end

  def ends_at_greater_thans_starts_at
    if starts_at > ends_at
      errors.add(:ends_at, :invalid)
    end
  end
end
