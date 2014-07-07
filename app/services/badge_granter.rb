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

    find_by = { badge_id: @badge.id, user_id: @user.id }

    if @badge.multiple_grant?
      find_by[:post_id] = @post_id
    end

    user_badge = UserBadge.find_by(find_by)

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

  def self.backfill(badge)
    return unless badge.query.present?

    post_clause = badge.target_posts ? "AND q.post_id = ub.post_id" : ""
    post_id_field = badge.target_posts ? "q.post_id" : "NULL"

    sql = "DELETE FROM user_badges
           WHERE id in (
             SELECT ub.id
             FROM user_badges ub
             LEFT JOIN ( #{badge.query} ) q
             ON q.user_id = ub.user_id
              #{post_clause}
             WHERE ub.badge_id = :id AND q.user_id IS NULL
           )"

    Badge.exec_sql(sql, id: badge.id)

    sql = "INSERT INTO user_badges(badge_id, user_id, granted_at, granted_by_id, post_id)
            SELECT :id, q.user_id, q.granted_at, -1, #{post_id_field}
            FROM ( #{badge.query} ) q
            LEFT JOIN user_badges ub ON
              ub.badge_id = :id AND ub.user_id = q.user_id
              #{post_clause}
            WHERE ub.badge_id IS NULL AND q.user_id <> -1
            RETURNING id, user_id, granted_at
            "

    builder = SqlBuilder.new(sql)
    builder.map_exec(OpenStruct, id: badge.id).each do |row|

      # old bronze badges do not matter
      next if badge.badge_type_id == BadgeType::Bronze and row.granted_at < 2.days.ago

      notification = Notification.create!(
                        user_id: row.user_id,
                        notification_type: Notification.types[:granted_badge],
                        data: { badge_id: badge.id, badge_name: badge.name }.to_json )

      Badge.exec_sql("UPDATE user_badges SET notification_id = :notification_id WHERE id = :id",
                      notification_id: notification.id,
                      id: row.id
                    )
    end

    badge.reset_grant_count!

  end

end
