module LimitedEdit
  extend ActiveSupport::Concern

  def edit_time_limit_expired?
    if created_at && SiteSetting.post_edit_time_limit.to_i > 0
      created_at < SiteSetting.post_edit_time_limit.to_i.minutes.ago
    else
      false
    end
  end
end
