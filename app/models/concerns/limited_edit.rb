# frozen_string_literal: true

module LimitedEdit
  extend ActiveSupport::Concern

  def edit_time_limit_expired?(user)
    return true if !user.guardian.trusted_with_post_edits?
    time_limit = user_time_limit(user)
    created_at && (time_limit > 0) && (created_at < time_limit.minutes.ago)
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
