
class Flag < PostAction
  self.table_name = :flags

  validates_presence_of :post_action_type_id
  after_save :enforce_rules

  # === BEGIN CRAZY SUBCLASSING MADNESS === #

  def self.sti_name
    # apparently this works lol
    PostActionType.all_flag_type_ids
  end

  def self.type_condition(table = arel_table)
    table[:post_action_type_id].in(PostActionType.all_flag_type_ids)
  end

  def ensure_proper_type
    if post_action_type_id.present?
      raise ActiveRecord::ValidationError "Bad post_action_type_id value for Flag" unless
        PostActionType.all_flag_type_ids.include? post_action_type_id
    else
      write_attribute(:post_action_type_id, PostActionType.all_flag_type_ids.first)
    end
  end

  # === END CRAZY SUBCLASSING MADNESS === #

  before_create do
    raise AlreadyActed if PostAction.where(user_id: user_id)
                            .where(post_id: post_id)
                            .where(post_action_type_id: PostActionType.flag_types.values) # exclude PM
                            .where(deleted_at: nil)
                            .where(disagreed_at: nil)
                            .where(targets_topic: targets_topic)
                            .exists?
  end

  def is_bookmark?
    false
  end

  def is_like?
    false
  end

  def is_flag?
    true
  end

  def is_private_message?
    post_action_type_id == PostActionType.types[:notify_user] ||
    post_action_type_id == PostActionType.types[:notify_moderators]
  end

  def enforce_rules
    post = Post.with_deleted.where(id: post_id).first
    Flag.auto_close_if_threshold_reached(post.topic)
    Flag.auto_hide_if_needed(user, post, post_action_type_key)
    SpamRulesEnforcer.enforce!(post.user) if post_action_type_key == :spam
  end

  def self.flag_count_by_date(start_date, end_date, category_id=nil)
    result = Flag.where('flags.created_at >= ? AND flags.created_at <= ?', start_date, end_date)
    result = result.where(post_action_type_id: PostActionType.flag_types.values)
    result = result.joins(post: :topic).where("topics.category_id = ?", category_id) if category_id
    result.group('date(flags.created_at)')
      .order('date(flags.created_at)')
      .count
  end

  def self.update_flagged_posts_count
    posts_flagged_count = Flag.active
                            .flags
                            .joins(post: :topic)
                            .where('posts.deleted_at' => nil)
                            .where('topics.deleted_at' => nil)
                            .count('DISTINCT posts.id')

    $redis.set('posts_flagged_count', posts_flagged_count)
    user_ids = User.staff.pluck(:id)
    MessageBus.publish('/flagged_counts', { total: posts_flagged_count }, { user_ids: user_ids })
  end

  def self.flagged_posts_count
    $redis.get('posts_flagged_count').to_i
  end

  def self.active_flags_counts_for(collection)
    return {} if collection.blank?

    collection_ids = collection.map(&:id)

    post_actions = Flag.active.flags.where(post_id: collection_ids)

    user_actions = {}
    post_actions.each do |post_action|
      user_actions[post_action.post_id] ||= {}
      user_actions[post_action.post_id][post_action.post_action_type_id] ||= []
      user_actions[post_action.post_id][post_action.post_action_type_id] << post_action
    end

    user_actions
  end

  def self.agree_flags!(post, moderator, delete_post=false)
    actions = Flag.active
                .where(post_id: post.id)
                .where(post_action_type_id: PostActionType.flag_types.values)

    trigger_spam = false
    actions.each do |action|
      action.agreed_at = Time.zone.now
      action.agreed_by_id = moderator.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(moderator, :agreed, delete_post)
      @trigger_spam = true if action.post_action_type_id == PostActionType.types[:spam]
    end

    DiscourseEvent.trigger(:confirmed_spam_post, post) if @trigger_spam

    update_flagged_posts_count
  end

  def self.clear_flags!(post, moderator)
    # -1 is the automatic system cleary
    action_type_ids = moderator.id == -1 ?
      PostActionType.auto_action_flag_types.values :
      PostActionType.flag_types.values

    actions = Flag.where(post_id: post.id)
                .where(post_action_type_id: action_type_ids)

    actions.each do |action|
      action.disagreed_at = Time.zone.now
      action.disagreed_by_id = moderator.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(moderator, :disagreed)
    end

    # reset all cached counters
    f = action_type_ids.map { |t| ["#{PostActionType.types[t]}_count", 0] }
    Post.with_deleted.where(id: post.id).update_all(Hash[*f.flatten])

    update_flagged_posts_count
  end

  def self.defer_flags!(post, moderator, delete_post=false)
    actions = Flag.active
                .where(post_id: post.id)
                .where(post_action_type_id: PostActionType.flag_types.values)

    actions.each do |action|
      action.deferred_at = Time.zone.now
      action.deferred_by_id = moderator.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(moderator, :deferred, delete_post)
    end

    update_flagged_posts_count
  end

  def add_moderator_post_if_needed(moderator, disposition, delete_post=false)
    return unless SiteSetting.auto_respond_to_flag_actions
    return if related_post.nil? || related_post.topic.nil?
    return if staff_already_replied?(related_post.topic)
    message_key = "flags_dispositions.#{disposition}"
    message_key << "_and_deleted" if delete_post
    related_post.topic.add_moderator_post(moderator, I18n.t(message_key))
  end

  def staff_already_replied?(topic)
    topic.posts.where("user_id IN (SELECT id FROM users WHERE moderator OR admin) OR (post_type != :regular_post_type)", regular_post_type: Post.types[:regular]).exists?
  end

  def self.create_message_for_post_action(user, post, post_action_type_id, opts)
    post_action_type = PostActionType.types[post_action_type_id]

    return unless opts[:message] && [:notify_moderators, :notify_user, :spam].include?(post_action_type)

    title = I18n.t("post_action_types.#{post_action_type}.email_title", title: post.topic.title)
    body = I18n.t("post_action_types.#{post_action_type}.email_body", message: opts[:message], link: "#{Discourse.base_url}#{post.url}")

    title = title.truncate(255, separator: /\s/)

    opts = {
      archetype: Archetype.private_message,
      title: title,
      raw: body
    }

    if [:notify_moderators, :spam].include?(post_action_type)
      opts[:subtype] = TopicSubtype.notify_moderators
      opts[:target_group_names] = "moderators"
    else
      opts[:subtype] = TopicSubtype.notify_user
      opts[:target_usernames] = if post_action_type == :notify_user
                                  post.user.username
                                elsif post_action_type != :notify_moderators
                                  # this is a hack to allow a PM with no recipients, we should think through
                                  # a cleaner technique, a PM with myself is valid for flagging
                                  'x'
                                end
    end

    PostCreator.new(user, opts).create.id
  end

  # Returns the flag counts for a post, taking into account that some users
  # can weigh flags differently.
  def self.flag_counts_for(post_id)
    flag_counts = exec_sql("SELECT SUM(CASE
                                         WHEN pa.disagreed_at IS NULL AND pa.staff_took_action THEN :flags_required_to_hide_post
                                         WHEN pa.disagreed_at IS NULL AND NOT pa.staff_took_action THEN 1
                                         ELSE 0
                                       END) AS new_flags,
                                   SUM(CASE
                                         WHEN pa.disagreed_at IS NOT NULL AND pa.staff_took_action THEN :flags_required_to_hide_post
                                         WHEN pa.disagreed_at IS NOT NULL AND NOT pa.staff_took_action THEN 1
                                         ELSE 0
                                       END) AS old_flags
                            FROM flags AS pa
                              INNER JOIN users AS u ON u.id = pa.user_id
                            WHERE pa.post_id = :post_id
                              AND pa.post_action_type_id IN (:post_action_types)
                              AND pa.deleted_at IS NULL",
                           post_id: post_id,
                           post_action_types: PostActionType.auto_action_flag_types.values,
                           flags_required_to_hide_post: SiteSetting.flags_required_to_hide_post).first

    [flag_counts['old_flags'].to_i, flag_counts['new_flags'].to_i]
  end

  def self.auto_close_if_threshold_reached(topic)
    return if topic.nil? || topic.closed?

    flags = Flag.active
              .flags
              .joins(:post)
              .where("posts.topic_id = ?", topic.id)
              .where.not(user_id: Discourse::SYSTEM_USER_ID)
              .group("flags.user_id")
              .pluck("flags.user_id, COUNT(post_id)")

    # we need a minimum number of unique flaggers
    return if flags.count < SiteSetting.num_flaggers_to_close_topic
    # we need a minimum number of flags
    return if flags.sum { |f| f[1] } < SiteSetting.num_flags_to_close_topic

    # the threshold has been reached, we will close the topic waiting for intervention
    message = I18n.t("temporarily_closed_due_to_flags")
    topic.update_status("closed", true, Discourse.system_user, message: message)
  end

  def self.auto_hide_if_needed(acting_user, post, post_action_type)
    return if post.hidden

    if post_action_type == :spam &&
      acting_user.has_trust_level?(TrustLevel[3]) &&
      post.user.trust_level == TrustLevel[0]

      hide_post!(post, post_action_type, Post.hidden_reasons[:flagged_by_tl3_user])

    elsif PostActionType.auto_action_flag_types.include?(post_action_type) &&
      SiteSetting.flags_required_to_hide_post > 0

      old_flags, new_flags = PostAction.flag_counts_for(post.id)

      if new_flags >= SiteSetting.flags_required_to_hide_post
        hide_post!(post, post_action_type, guess_hide_reason(old_flags))
      end
    end
  end

  def self.hide_post!(post, post_action_type, reason=nil)
    return if post.hidden

    unless reason
      old_flags,_ = Flag.flag_counts_for(post.id)
      reason = guess_hide_reason(old_flags)
    end

    Post.where(id: post.id).update_all(["hidden = true, hidden_at = ?, hidden_reason_id = COALESCE(hidden_reason_id, ?)", Time.now, reason])
    Topic.where("id = :topic_id AND NOT EXISTS(SELECT 1 FROM POSTS WHERE topic_id = :topic_id AND NOT hidden)", topic_id: post.topic_id).update_all(visible: false)

    # inform user
    if post.user
      options = {
        url: post.url,
        edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts,
        flag_reason: I18n.t("flag_reasons.#{post_action_type}"),
      }
      SystemMessage.create(post.user, :post_hidden, options)
    end
  end

  def self.guess_hide_reason(old_flags)
    old_flags > 0 ?
      Post.hidden_reasons[:flag_threshold_reached_again] :
      Post.hidden_reasons[:flag_threshold_reached]
  end

  def self.target_moderators
    Group[:moderators].name
  end
end

# == Schema Information
#
# Table name: flags
#
#  id                  :integer          primary key
#  post_id             :integer
#  user_id             :integer
#  post_action_type_id :integer
#  deleted_at          :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  deleted_by_id       :integer
#  related_post_id     :integer
#  staff_took_action   :boolean
#  deferred_by_id      :integer
#  targets_topic       :boolean
#  agreed_at           :datetime
#  agreed_by_id        :integer
#  deferred_at         :datetime
#  disagreed_at        :datetime
#  disagreed_by_id     :integer
#
