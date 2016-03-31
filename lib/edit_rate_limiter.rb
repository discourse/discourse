require 'rate_limiter'
class EditRateLimiter < RateLimiter
  def initialize(user)
    super(user, "edit-post", SiteSetting.max_edits_per_day, 1.day.to_i)
  end

  def build_key(type)
    "#{super(type)}:#{Date.today}"
  end
end
