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
        seq = 0
        if @badge.multiple_grant?
          seq = UserBadge.where(badge: @badge, user: @user).maximum(:seq)
          seq = (seq || -1) + 1
        end

        user_badge = UserBadge.create!(badge: @badge,
                                       user: @user,
                                       granted_by: @granted_by,
                                       granted_at: Time.now,
                                       post_id: @post_id,
                                       seq: seq)

        if @granted_by != Discourse.system_user
          StaffActionLogger.new(@granted_by).log_badge_grant(user_badge)
        end

        if SiteSetting.enable_badges?
          notification = @user.notifications.create(
                  notification_type: Notification.types[:granted_badge],
                  data: { badge_id: @badge.id, badge_name: @badge.name }.to_json)
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

  def self.queue_badge_grant(type,opt)
    return unless SiteSetting.enable_badges
    payload = nil

    case type
    when Badge::Trigger::PostRevision
      post = opt[:post]
      payload = {
        type: "PostRevision",
        post_ids: [post.id]
      }
    when Badge::Trigger::UserChange
      user = opt[:user]
      payload = {
        type: "UserChange",
        user_ids: [user.id]
      }
    when Badge::Trigger::TrustLevelChange
      user = opt[:user]
      payload = {
        type: "TrustLevelChange",
        user_ids: [user.id]
      }
    when Badge::Trigger::PostAction
      action = opt[:post_action]
      payload = {
        type: "PostAction",
        post_ids: [action.post_id, action.related_post_id].compact!
      }
    end

    $redis.lpush queue_key, payload.to_json if payload
  end

  def self.clear_queue!
    $redis.del queue_key
  end

  def self.process_queue!
    limit = 1000
    items = []
    while limit > 0 && item = $redis.lpop(queue_key)
      items << JSON.parse(item)
      limit -= 1
    end

    items = items.group_by{|i| i["type"]}

    items.each do |type, list|
      post_ids = list.map{|i| i["post_ids"]}.flatten.compact.uniq
      user_ids = list.map{|i| i["user_ids"]}.flatten.compact.uniq

      next unless post_ids.present? || user_ids.present?
      find_by_type(type).each{ |badge|
        backfill(badge, post_ids: post_ids, user_ids: user_ids)
      }
    end
  end

  def self.find_by_type(type)
    id = "Badge::Trigger::#{type}".constantize
    Badge.where(trigger: id)
  end

  def self.queue_key
    "badge_queue".freeze
  end

  # Options:
  #   :target_posts - whether the badge targets posts
  #   :trigger - the Badge::Trigger id
  def self.contract_checks!(sql, opts = {})
    return unless sql.present?
    if Badge::Trigger.uses_post_ids?(opts[:trigger])
      raise("Contract violation:\nQuery triggers on posts, but does not reference the ':post_ids' array") unless sql.match(/:post_ids/)
      raise "Contract violation:\nQuery triggers on posts, but references the ':user_ids' array" if sql.match(/:user_ids/)
    end
    if Badge::Trigger.uses_user_ids?(opts[:trigger])
      raise "Contract violation:\nQuery triggers on users, but does not reference the ':user_ids' array" unless sql.match(/:user_ids/)
      raise "Contract violation:\nQuery triggers on users, but references the ':post_ids' array" if sql.match(/:post_ids/)
    end
    if opts[:trigger] && !Badge::Trigger.is_none?(opts[:trigger])
      raise "Contract violation:\nQuery is triggered, but does not reference the ':backfill' parameter.\n(Hint: if :backfill is TRUE, you should ignore the :post_ids/:user_ids)" unless sql.match(/:backfill/)
    end

    # TODO these three conditions have a lot of false negatives
    if opts[:target_posts]
      raise "Contract violation:\nQuery targets posts, but does not return a 'post_id' column" unless sql.match(/post_id/)
    end
    raise "Contract violation:\nQuery does not return a 'user_id' column" unless sql.match(/user_id/)
    raise "Contract violation:\nQuery does not return a 'granted_at' column" unless sql.match(/granted_at/)
    raise "Contract violation:\nQuery ends with a semicolon. Remove the semicolon; your sql will be used in a subquery." if sql.match(/;\s*\z/)
  end

  # Options:
  #   :target_posts - whether the badge targets posts
  #   :trigger - the Badge::Trigger id
  #   :explain - return the EXPLAIN query
  def self.preview(sql, opts = {})
    params = {user_ids: [], post_ids: [], backfill: true}

    BadgeGranter.contract_checks!(sql, opts)

    # hack to allow for params, otherwise sanitizer will trigger sprintf
    count_sql = "SELECT COUNT(*) count FROM (#{sql}) q WHERE :backfill = :backfill"
    grant_count = SqlBuilder.map_exec(OpenStruct, count_sql, params).first.count.to_i

    grants_sql =
     if opts[:target_posts]
      "SELECT u.id, u.username, q.post_id, t.title, q.granted_at
    FROM(#{sql}) q
    JOIN users u on u.id = q.user_id
    LEFT JOIN badge_posts p on p.id = q.post_id
    LEFT JOIN topics t on t.id = p.topic_id
    WHERE :backfill = :backfill
    LIMIT 10"
     else
      "SELECT u.id, u.username, q.granted_at
    FROM(#{sql}) q
    JOIN users u on u.id = q.user_id
    WHERE :backfill = :backfill
    LIMIT 10"
     end

    query_plan = nil
    # HACK: active record is weird, force it to go down the sanitization path that cares not for % stuff
    query_plan = ActiveRecord::Base.exec_sql("EXPLAIN #{sql} /*:backfill*/", params) if opts[:explain]

    sample = SqlBuilder.map_exec(OpenStruct, grants_sql, params).map(&:to_h)

    sample.each do |result|
      raise "Query returned a non-existent user ID:\n#{result[:id]}" unless User.find(result[:id]).present?
      raise "Query did not return a badge grant time\n(Try using 'current_timestamp granted_at')" unless result[:granted_at]
      if opts[:target_posts]
        raise "Query did not return a post ID" unless result[:post_id]
        raise "Query returned a non-existent post ID:\n#{result[:post_id]}" unless Post.find(result[:post_id]).present?
      end
    end

    {grant_count: grant_count, sample: sample, query_plan: query_plan}
  rescue => e
    {errors: e.message}
  end

  MAX_ITEMS_FOR_DELTA = 200
  def self.backfill(badge, opts=nil)
    return unless SiteSetting.enable_badges
    return unless badge.query.present? && badge.enabled

    post_ids = user_ids = nil

    post_ids = opts[:post_ids] if opts
    user_ids = opts[:user_ids] if opts

    # safeguard fall back to full backfill if more than 200
    if (post_ids && post_ids.length > MAX_ITEMS_FOR_DELTA) ||
       (user_ids && user_ids.length > MAX_ITEMS_FOR_DELTA)
      post_ids = nil
      user_ids = nil
    end

    post_ids = nil unless post_ids.present?
    user_ids = nil unless user_ids.present?

    full_backfill = !user_ids && !post_ids

    post_clause = badge.target_posts ? "AND (q.post_id = ub.post_id OR NOT :multiple_grant)" : ""
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

    Badge.exec_sql(sql, id: badge.id,
                        post_ids: [-1],
                        user_ids: [-2],
                        backfill: true,
                        multiple_grant: true # cheat here, cause we only run on backfill and are deleting
                  ) if badge.auto_revoke && full_backfill

    sql = "INSERT INTO user_badges(badge_id, user_id, granted_at, granted_by_id, post_id)
            SELECT :id, q.user_id, q.granted_at, -1, #{post_id_field}
            FROM ( #{badge.query} ) q
            LEFT JOIN user_badges ub ON
              ub.badge_id = :id AND ub.user_id = q.user_id
              #{post_clause}
            /*where*/
            RETURNING id, user_id, granted_at
            "

    builder = SqlBuilder.new(sql)
    builder.where("ub.badge_id IS NULL AND q.user_id <> -1")

    if (post_ids || user_ids) && !badge.query.include?(":backfill")
      Rails.logger.warn "Your triggered badge query for #{badge.name} does not include the :backfill param, skipping!"
      return
    end

    if (post_ids && !badge.query.include?(":post_ids"))
      Rails.logger.warn "Your triggered badge query for #{badge.name} does not include the :post_ids param, skipping!"
      return
    end

    if (user_ids && !badge.query.include?(":user_ids"))
      Rails.logger.warn "Your triggered badge query for #{badge.name} does not include the :user_ids param, skipping!"
      return
    end

    builder.map_exec(OpenStruct, id: badge.id,
                                 multiple_grant: badge.multiple_grant,
                                 backfill: full_backfill,
                                 post_ids: post_ids || [-2],
                                 user_ids: user_ids || [-2]).each do |row|

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


  def self.revoke_ungranted_titles!
    Badge.exec_sql("UPDATE users SET title = ''
                   WHERE NOT title IS NULL AND
                         title <> '' AND
                         EXISTS (
                            SELECT 1
                            FROM user_profiles
                            WHERE user_id = users.id AND badge_granted_title
                         ) AND
                         title NOT IN (
                            SELECT name
                            FROM badges
                            WHERE allow_title AND enabled AND
                              badges.id IN (SELECT badge_id FROM user_badges ub where ub.user_id = users.id)
                        )
                   ")
  end

end
