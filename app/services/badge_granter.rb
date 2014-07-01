class BadgeGranter

  def initialize(badge, user, opts={})
    @badge, @user, @opts = badge, user, opts
    @granted_by = opts[:granted_by] || Discourse.system_user
    @post_id = opts[:post_id]
  end

  def self.grant(badge, user, opts={})
    BadgeGranter.new(badge, user, opts).grant
  end

  def grant
    return if @granted_by and !Guardian.new(@granted_by).can_grant_badges?(@user)

    user_badge = UserBadge.find_by(badge_id: @badge.id, user_id: @user.id, post_id: @post_id)

    if user_badge.nil? || (@badge.multiple_grant? && @post_id.nil?)
      UserBadge.transaction do
        user_badge = UserBadge.create!(badge: @badge, user: @user,
                                       granted_by: @granted_by,
                                       granted_at: Time.now,
                                       post_id: @post_id)

        if @granted_by != Discourse.system_user
          StaffActionLogger.new(@granted_by).log_badge_grant(user_badge)
        end

        if SiteSetting.enable_badges?
          notification = @user.notifications.create(notification_type: Notification.types[:granted_badge], data: { badge_id: @badge.id, badge_name: @badge.name }.to_json)
          user_badge.update_attributes notification_id: notification.id
        end
      end
    end

    user_badge
  end

  def self.revoke(user_badge, options={})
    UserBadge.transaction do
      user_badge.destroy!
      if options[:revoked_by]
        StaffActionLogger.new(options[:revoked_by]).log_badge_revoke(user_badge)
      end

      # If the user's title is the same as the badge name, remove their title.
      if user_badge.user.title == user_badge.badge.name
        user_badge.user.title = nil
        user_badge.user.save!
      end
    end
  end

  def self.update_badges(args)
    Jobs.enqueue(:update_badges, args)
  end


  def self.backfill_like_badges
    Badge.like_badge_info.each do |info|
      sql = "
      DELETE FROM user_badges
      WHERE badge_id = :id AND
      NOT EXISTS (SELECT 1 FROM posts p
                  JOIN topics t on p.topic_id = t.id
                  WHERE p.deleted_at IS NULL AND
                        t.deleted_at IS NULL AND
                        t.visible AND
                        post_id = p.id AND
                        p.like_count >= :count
                  )
      "

      Badge.exec_sql(sql, info)

      sql = "
      INSERT INTO user_badges(badge_id, user_id, granted_at, granted_by_id, post_id)
      SELECT :id, p.user_id, :now, -1, p.id
      FROM posts p
      JOIN topics t on p.topic_id = t.id
      WHERE p.deleted_at IS NULL AND
            t.deleted_at IS NULL AND
            t.visible AND
            p.like_count >= :count AND
            NOT EXISTS (SELECT 1 FROM user_badges ub
                        WHERE ub.post_id = p.id AND
                        ub.badge_id = :id AND
                        ub.user_id = p.user_id)
      "

      Badge.exec_sql(sql, info.merge(now: Time.now))

      sql = "
      UPDATE badges b
      SET grant_count = (SELECT COUNT(*) FROM user_badges WHERE badge_id = :id)
      WHERE b.id = :id
      "

      Badge.exec_sql(sql, info)
    end
  end

end
