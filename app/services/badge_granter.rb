class BadgeGranter

  def initialize(badge, user, opts={})
    @badge, @user, @opts = badge, user, opts
    @granted_by = opts[:granted_by] || Discourse.system_user
  end

  def self.grant(badge, user, opts={})
    BadgeGranter.new(badge, user, opts).grant
  end

  def grant
    return if @granted_by and !Guardian.new(@granted_by).can_grant_badges?(@user)

    user_badge = nil

    UserBadge.transaction do
      user_badge = UserBadge.create!(badge: @badge, user: @user,
                                     granted_by: @granted_by, granted_at: Time.now)

      Badge.increment_counter 'grant_count', @badge.id
    end

    user_badge
  end

  def self.revoke(user_badge)
    UserBadge.transaction do
      user_badge.destroy!
      Badge.decrement_counter 'grant_count', user_badge.badge.id
    end
  end

end
