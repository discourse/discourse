# frozen_string_literal: true

module LimitedEdit
  extend ActiveSupport::Concern

  def edit_time_limit_expired?(user)
    time_limit = user_time_limit(user)
    if user.trust_level < SiteSetting.min_trust_to_edit_post
      true
    elsif created_at && time_limit > 0
      created_at < time_limit.minutes.ago
    else
      false
    end
  end

  private

  def user_time_limit(user)
    if user.trust_level < 2
      SiteSetting.post_edit_time_limit.to_i
    else
      SiteSetting.tl2_post_edit_time_limit.to_i
    end
  end
end
