require 'rate_limiter'
class EditRateLimiter < RateLimiter
  def initialize(user)
    super(user, "edit-post:#{Date.today.to_s}", SiteSetting.max_edits_per_day, 1.day.to_i)
  end
end
