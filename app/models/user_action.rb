class UserAction < ActiveRecord::Base

  belongs_to :user
  belongs_to :target_post, class_name: "Post"
  belongs_to :target_topic, class_name: "Topic"

  validates_presence_of :action_type
  validates_presence_of :user_id

  LIKE = 1
  WAS_LIKED = 2
  BOOKMARK = 3
  NEW_TOPIC = 4
  REPLY = 5
  RESPONSE = 6
  MENTION = 7
  QUOTE = 9
  EDIT = 11
  NEW_PRIVATE_MESSAGE = 12
  GOT_PRIVATE_MESSAGE = 13
  PENDING = 14
  SOLVED = 15
  ASSIGNED = 16

  ORDER = Hash[*[
    GOT_PRIVATE_MESSAGE,
    NEW_PRIVATE_MESSAGE,
    PENDING,
    NEW_TOPIC,
    REPLY,
    RESPONSE,
    LIKE,
    WAS_LIKED,
    MENTION,
    QUOTE,
    BOOKMARK,
    EDIT,
    SOLVED,
    ASSIGNED,
  ].each_with_index.to_a.flatten]

  def self.last_action_in_topic(user_id, topic_id)
    UserAction.where(user_id: user_id,
                     target_topic_id: topic_id,
                     action_type: [RESPONSE, MENTION, QUOTE]).order('created_at DESC').pluck(:target_post_id).first
  end

  def self.stats(user_id, guardian)

    # Sam: I tried this in AR and it got complex
    builder = DB.build <<~SQL

      SELECT action_type, COUNT(*) count
      FROM user_actions a
      LEFT JOIN topics t ON t.id = a.target_topic_id
      LEFT JOIN posts p on p.id = a.target_post_id
      LEFT JOIN posts p2 on p2.topic_id = a.target_topic_id and p2.post_number = 1
      LEFT JOIN categories c ON c.id = t.category_id
      /*where*/
      GROUP BY action_type
    SQL

    builder.where('a.user_id = :user_id', user_id: user_id)

    apply_common_filters(builder, user_id, guardian)

    results = builder.query
    results.sort! { |a, b| ORDER[a.action_type] <=> ORDER[b.action_type] }
    results
  end

  def self.private_messages_stats(user_id, guardian)
    return unless guardian.can_see_private_messages?(user_id)

    # list the stats for: all/mine/unread/groups (topic-based)

    sql = <<-SQL
      SELECT COUNT(*) "all"
           , SUM(CASE WHEN t.user_id = :user_id THEN 1 ELSE 0 END) "mine"
           , SUM(CASE WHEN tu.last_read_post_number IS NULL OR tu.last_read_post_number < t.highest_post_number THEN 1 ELSE 0 END) "unread"
        FROM topics t
   LEFT JOIN topic_users tu ON t.id = tu.topic_id AND tu.user_id = :user_id
       WHERE t.deleted_at IS NULL
         AND t.archetype = 'private_message'
         AND t.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = :user_id)
    SQL

    # map is there due to count returning nil
    all, mine, unread = DB.query_single(sql, user_id: user_id).map(&:to_i)

    sql = <<-SQL
      SELECT  g.name, COUNT(*) "count"
        FROM topics t
        JOIN topic_allowed_groups tg ON topic_id = t.id
        JOIN group_users gu ON gu.user_id = :user_id AND gu.group_id = tg.group_id
        JOIN groups g ON g.id = gu.group_id
       WHERE deleted_at IS NULL
         AND archetype = 'private_message'
       GROUP BY g.name
    SQL

    result = { all: all, mine: mine, unread: unread }

    DB.query(sql, user_id: user_id).each do |row|
      (result[:groups] ||= []) << { name: row.name, count: row.count.to_i }
    end

    result

  end

  def self.count_daily_engaged_users(start_date = nil, end_date = nil)
    result = select(:user_id)
      .distinct
      .where(action_type: [LIKE, NEW_TOPIC, REPLY, NEW_PRIVATE_MESSAGE])

    if start_date && end_date
      result = result.group('date(created_at)')
      result = result.where('created_at > ? AND created_at < ?', start_date, end_date)
      result = result.order('date(created_at)')
    end

    result.count
  end

  def self.stream_item(action_id, guardian)
    stream(action_id: action_id, guardian: guardian).first
  end

  NULL_QUEUED_STREAM_COLS = %i{
    cooked
    uploaded_avatar_id
    acting_name
    acting_username
    acting_user_id
    target_name
    target_username
    target_user_id
    post_number
    post_id
    deleted
    hidden
    post_type
    action_type
    action_code
    action_code_who
    topic_closed
    topic_id
    topic_archived
  }.map! { |s|  "NULL as #{s}" }.join(", ")

  def self.stream_queued(opts = nil)
    opts ||= {}

    offset = opts[:offset] || 0
    limit = opts[:limit] || 60

    # this is somewhat ugly, but the serializer wants all these columns
    # it is more correct to have an object with all the fields needed
    # cause then we can catch and change if we ever add columns
    builder = DB.build <<~SQL
      SELECT
        a.id,
        t.title,
        a.action_type,
        a.created_at,
        t.id topic_id,
        u.username,
        u.name,
        u.id AS user_id,
        qp.raw,
        t.category_id,
        #{NULL_QUEUED_STREAM_COLS}
      FROM user_actions as a
      JOIN queued_posts AS qp ON qp.id = a.queued_post_id
      LEFT OUTER JOIN topics t on t.id = qp.topic_id
      JOIN users u on u.id = a.user_id
      LEFT JOIN categories c on c.id = t.category_id
      /*where*/
      /*order_by*/
      /*offset*/
      /*limit*/
    SQL

    builder
      .where('a.user_id = :user_id', user_id: opts[:user_id].to_i)
      .where('action_type = :pending', pending: UserAction::PENDING)
      .order_by("a.created_at desc")
      .offset(offset.to_i)
      .limit(limit.to_i)
      .query
  end

  def self.stream(opts = nil)
    opts ||= {}

    action_types = opts[:action_types]
    user_id = opts[:user_id]
    action_id = opts[:action_id]
    guardian = opts[:guardian]
    ignore_private_messages = opts[:ignore_private_messages]
    offset = opts[:offset] || 0
    limit = opts[:limit] || 60
    acting_username = opts[:acting_username]

    # Acting user columns. Can be extended by plugins to include custom avatar
    # columns
    acting_cols = [
      'u.id AS acting_user_id',
      'u.name AS acting_name'
    ]

    AvatarLookup.lookup_columns.each do |c|
      next if c == :id || c['.']
      acting_cols << "u.#{c} AS acting_#{c}"
    end

    # The weird thing is that target_post_id can be null, so it makes everything
    #  ever so more complex. Should we allow this, not sure.
    builder = DB.build <<~SQL
      SELECT
        a.id,
        t.title, a.action_type, a.created_at, t.id topic_id,
        t.closed AS topic_closed, t.archived AS topic_archived,
        a.user_id AS target_user_id, au.name AS target_name, au.username AS target_username,
        coalesce(p.post_number, 1) post_number, p.id as post_id,
        p.reply_to_post_number,
        pu.username, pu.name, pu.id user_id,
        pu.uploaded_avatar_id,
        #{acting_cols.join(', ')},
        coalesce(p.cooked, p2.cooked) cooked,
        CASE WHEN coalesce(p.deleted_at, p2.deleted_at, t.deleted_at) IS NULL THEN false ELSE true END deleted,
        p.hidden,
        p.post_type,
        p.action_code,
        pc.value AS action_code_who,
        p.edit_reason,
        t.category_id
      FROM user_actions as a
      JOIN topics t on t.id = a.target_topic_id
      LEFT JOIN posts p on p.id = a.target_post_id
      JOIN posts p2 on p2.topic_id = a.target_topic_id and p2.post_number = 1
      JOIN users u on u.id = a.acting_user_id
      JOIN users pu on pu.id = COALESCE(p.user_id, t.user_id)
      JOIN users au on au.id = a.user_id
      LEFT JOIN categories c on c.id = t.category_id
      LEFT JOIN post_custom_fields pc ON pc.post_id = a.target_post_id AND pc.name = 'action_code_who'
      /*where*/
      /*order_by*/
      /*offset*/
      /*limit*/
    SQL

    apply_common_filters(builder, user_id, guardian, ignore_private_messages)

    if action_id
      builder.where("a.id = :id", id: action_id.to_i)
    else
      builder.where("a.user_id = :user_id", user_id: user_id.to_i)
      builder.where("a.action_type in (:action_types)", action_types: action_types) if action_types && action_types.length > 0

      if acting_username
        builder.where("u.username_lower = :acting_username",
          acting_username: acting_username.downcase
        )
      end

      unless SiteSetting.enable_mentions?
        builder.where("a.action_type <> :mention_type", mention_type: UserAction::MENTION)
      end

      builder
        .order_by("a.created_at desc")
        .offset(offset.to_i)
        .limit(limit.to_i)
    end

    builder.query
  end

  def self.log_action!(hash)
    required_parameters = [:action_type, :user_id, :acting_user_id]

    if hash[:action_type] == UserAction::PENDING
      required_parameters << :queued_post_id
    else
      required_parameters << :target_post_id
      required_parameters << :target_topic_id
    end

    require_parameters(hash, *required_parameters)

    transaction(requires_new: true) do
      begin
        # TODO there are conditions when this is called and user_id was already rolled back and is invalid.

        # protect against dupes, for some reason this is failing in some cases
        action = self.find_by(hash.select { |k, _| required_parameters.include?(k) })
        return action if action

        action = self.new(hash)

        if hash[:created_at]
          action.created_at = hash[:created_at]
        end
        action.save!

        user_id = hash[:user_id]

        topic = Topic.includes(:category).find_by(id: hash[:target_topic_id])

        if topic && !topic.private_message?
          update_like_count(user_id, hash[:action_type], 1)
        end

        # move into Topic perhaps
        group_ids = nil
        if topic && topic.category && topic.category.read_restricted
          group_ids = topic.category.groups.pluck("groups.id")
        end

        if action.user
          MessageBus.publish("/u/#{action.user.username.downcase}", action.id, user_ids: [user_id], group_ids: group_ids)
        end

        action

      rescue ActiveRecord::RecordNotUnique
        # can happen, don't care already logged
        raise ActiveRecord::Rollback
      end
    end
  end

  def self.remove_action!(hash)
    require_parameters(hash, :action_type, :user_id, :acting_user_id, :target_topic_id, :target_post_id)
    if action = UserAction.find_by(hash.except(:created_at))
      action.destroy
      MessageBus.publish("/user/#{hash[:user_id]}", user_action_id: action.id, remove: true)
    end

    if !Topic.where(id: hash[:target_topic_id], archetype: Archetype.private_message).exists?
      update_like_count(hash[:user_id], hash[:action_type], -1)
    end
  end

  def self.synchronize_target_topic_ids(post_ids = nil)

    # nuke all dupes, using magic
    builder = DB.build <<~SQL
      DELETE FROM user_actions USING user_actions ua2
      /*where*/
    SQL

    builder.where <<~SQL
      user_actions.action_type = ua2.action_type AND
      user_actions.user_id = ua2.user_id AND
      user_actions.acting_user_id = ua2.acting_user_id AND
      user_actions.target_post_id = ua2.target_post_id AND
      user_actions.target_post_id > 0 AND
      user_actions.id > ua2.id
    SQL

    if post_ids
      builder.where("user_actions.target_post_id in (:post_ids)", post_ids: post_ids)
    end

    builder.exec

    builder = DB.build <<~SQL
      UPDATE user_actions
      SET target_topic_id = (select topic_id from posts where posts.id = target_post_id)
      /*where*/
    SQL

    builder.where("target_topic_id <> (select topic_id from posts where posts.id = target_post_id)")
    if post_ids
      builder.where("target_post_id in (:post_ids)", post_ids: post_ids)
    end

    builder.exec
  end

  def self.ensure_consistency!
    self.synchronize_target_topic_ids
  end

  def self.update_like_count(user_id, action_type, delta)
    if action_type == LIKE
      UserStat.where(user_id: user_id).update_all("likes_given = likes_given + #{delta.to_i}")
    elsif action_type == WAS_LIKED
      UserStat.where(user_id: user_id).update_all("likes_received = likes_received + #{delta.to_i}")
    end
  end

  def self.apply_common_filters(builder, user_id, guardian, ignore_private_messages = false)
    # We never return deleted topics in activity
    builder.where("t.deleted_at is null")

    # We will return deleted posts though if the user can see it
    unless guardian.can_see_deleted_posts?
      builder.where("p.deleted_at is null and p2.deleted_at is null")

      current_user_id = -2
      current_user_id = guardian.user.id if guardian.user
      builder.where("NOT COALESCE(p.hidden, false) OR p.user_id = :current_user_id", current_user_id: current_user_id)
    end

    visible_post_types = Topic.visible_post_types(guardian.user)
    builder.where("COALESCE(p.post_type, p2.post_type) IN (:visible_post_types)", visible_post_types: visible_post_types)

    unless (guardian.user && guardian.user.id == user_id) || guardian.is_staff?
      builder.where("t.visible")
    end

    unless guardian.can_see_notifications?(User.where(id: user_id).first)
      builder.where("a.action_type not in (#{BOOKMARK})")
      builder.where('a.action_type <> :pending', pending: UserAction::PENDING)
    end

    if !guardian.can_see_private_messages?(user_id) || ignore_private_messages || !guardian.user
      builder.where("t.archetype <> :private_message", private_message: Archetype::private_message)
    else
      unless guardian.is_admin?
        sql = <<~SQL
        t.archetype <> :private_message OR
        EXISTS (
          SELECT 1 FROM topic_allowed_users tu WHERE tu.topic_id = t.id AND tu.user_id = :current_user_id
        ) OR
        EXISTS (
          SELECT 1 FROM topic_allowed_groups tg WHERE tg.topic_id = t.id AND tg.group_id IN (
            SELECT group_id FROM group_users gu WHERE gu.user_id = :current_user_id
          )
        )
        SQL

        builder.where(sql, private_message: Archetype::private_message, current_user_id: guardian.user.id)
      end
    end

    unless guardian.is_admin?
      allowed = guardian.secure_category_ids
      if allowed.present?
        builder.where("( c.read_restricted IS NULL OR
                         NOT c.read_restricted OR
                        (c.read_restricted and c.id in (:cats)) )", cats: guardian.secure_category_ids)
      else
        builder.where("(c.read_restricted IS NULL OR NOT c.read_restricted)")
      end
    end
  end

  def self.require_parameters(data, *params)
    params.each do |p|
      raise Discourse::InvalidParameters.new(p) if data[p].nil?
    end
  end
end

# == Schema Information
#
# Table name: user_actions
#
#  id              :integer          not null, primary key
#  action_type     :integer          not null
#  user_id         :integer          not null
#  target_topic_id :integer
#  target_post_id  :integer
#  target_user_id  :integer
#  acting_user_id  :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  queued_post_id  :integer
#
# Indexes
#
#  idx_unique_rows                                (action_type,user_id,target_topic_id,target_post_id,acting_user_id) UNIQUE
#  idx_user_actions_speed_up_user_all             (user_id,created_at,action_type)
#  index_user_actions_on_acting_user_id           (acting_user_id)
#  index_user_actions_on_target_post_id           (target_post_id)
#  index_user_actions_on_user_id_and_action_type  (user_id,action_type)
#
