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

    user_badge = UserBadge.find_by(badge_id: @badge.id, user_id: @user.id)

    unless user_badge
      UserBadge.transaction do
        user_badge = UserBadge.create!(badge: @badge, user: @user,
                                       granted_by: @granted_by, granted_at: Time.now)

        Badge.increment_counter 'grant_count', @badge.id
        if @granted_by != Discourse.system_user
          StaffActionLogger.new(@granted_by).log_badge_grant(user_badge)
        end

        if SiteSetting.enable_badges?
          @user.notifications.create(notification_type: Notification.types[:granted_badge],
                                     data: { badge_id: @badge.id,
                                             badge_name: @badge.name }.to_json)
        end
      end
    end

    user_badge
  end

  def self.revoke(user_badge, options={})
    UserBadge.transaction do
      user_badge.destroy!
      Badge.decrement_counter 'grant_count', user_badge.badge_id
      if options[:revoked_by]
        StaffActionLogger.new(options[:revoked_by]).log_badge_revoke(user_badge)
      end

      # If the user's title is the same as the badge name, remove their title.
      if user_badge.user.title == user_badge.badge.name
        user_badge.user.title = nil
        user_badge.user.save!
      end

      # Delete notification -- This is inefficient, but not very easy to optimize
      # unless the data hash is converted into a hstore.
      notification = user_badge.user.notifications.where(notification_type: Notification.types[:granted_badge]).where("data LIKE ?", "%" + user_badge.badge_id.to_s + "%").select {|n| n.data_hash["badge_id"] == user_badge.badge_id }.first
      notification && notification.destroy
    end
  end

  def self.update_badges(user, opts={})
    if opts.has_key?(:trust_level)
      # Update trust level badges.
      trust_level = opts[:trust_level]
      Badge.trust_level_badge_ids.each do |badge_id|
        user_badge = UserBadge.find_by(user_id: user.id, badge_id: badge_id)
        if user_badge
          # Revoke the badge if trust level was lowered.
          BadgeGranter.revoke(user_badge) if trust_level < badge_id
        else
          # Grant the badge if trust level was increased.
          badge = Badge.find(badge_id)
          BadgeGranter.grant(badge, user) if trust_level >= badge_id
        end
      end
    end
  end

end
