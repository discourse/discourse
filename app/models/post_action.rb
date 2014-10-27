require_dependency 'rate_limiter'
require_dependency 'system_message'

class PostAction < ActiveRecord::Base
  class AlreadyActed < StandardError; end

  include RateLimiter::OnCreateRecord
  include Trashable

  belongs_to :post
  belongs_to :user
  belongs_to :post_action_type
  belongs_to :related_post, class_name: 'Post'
  belongs_to :target_user, class_name: 'User'

  rate_limit :post_action_rate_limiter

  scope :spam_flags, -> { where(post_action_type_id: PostActionType.types[:spam]) }
  scope :flags, -> { where(post_action_type_id: PostActionType.notify_flag_type_ids) }
  scope :publics, -> { where(post_action_type_id: PostActionType.public_type_ids) }
  scope :active, -> { where(disagreed_at: nil, deferred_at: nil, agreed_at: nil, deleted_at: nil) }

  after_save :update_counters
  after_save :enforce_rules
  after_commit :notify_subscribers

  def disposed_by_id
    disagreed_by_id || agreed_by_id || deferred_by_id
  end

  def disposed_at
    disagreed_at || agreed_at || deferred_at
  end

  def disposition
    return :disagreed if disagreed_at
    return :agreed if agreed_at
    return :deferred if deferred_at
    nil
  end

  def self.update_flagged_posts_count
    posts_flagged_count = PostAction.active
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

  def self.counts_for(collection, user)
    return {} if collection.blank?

    collection_ids = collection.map(&:id)
    user_id = user.try(:id) || 0

    post_actions = PostAction.where(post_id: collection_ids, user_id: user_id)

    user_actions = {}
    post_actions.each do |post_action|
      user_actions[post_action.post_id] ||= {}
      user_actions[post_action.post_id][post_action.post_action_type_id] = post_action
    end

    user_actions
  end

  def self.active_flags_counts_for(collection)
    return {} if collection.blank?

    collection_ids = collection.map(&:id)

    post_actions = PostAction.active.flags.where(post_id: collection_ids)

    user_actions = {}
    post_actions.each do |post_action|
      user_actions[post_action.post_id] ||= {}
      user_actions[post_action.post_id][post_action.post_action_type_id] ||= []
      user_actions[post_action.post_id][post_action.post_action_type_id] << post_action
    end

    user_actions
  end

  def self.count_per_day_for_type(post_action_type, since_days_ago=30)
    unscoped.where(post_action_type_id: post_action_type)
            .where('created_at > ?', since_days_ago.days.ago)
            .group('date(created_at)')
            .order('date(created_at)')
            .count
  end

  def self.agree_flags!(post, moderator, delete_post=false)
    actions = PostAction.active
                        .where(post_id: post.id)
                        .where(post_action_type_id: PostActionType.flag_types.values)

    actions.each do |action|
      action.agreed_at = Time.zone.now
      action.agreed_by_id = moderator.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(moderator, :agreed, delete_post)
    end

    update_flagged_posts_count
  end

  def self.clear_flags!(post, moderator)
    # -1 is the automatic system cleary
    action_type_ids = moderator.id == -1 ?
        PostActionType.auto_action_flag_types.values :
        PostActionType.flag_types.values

    actions = PostAction.where(post_id: post.id)
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
    actions = PostAction.active
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
    return if related_post.nil?
    return if moderator_already_replied?(related_post.topic, moderator)
    message_key = "flags_dispositions.#{disposition}"
    message_key << "_and_deleted" if delete_post
    related_post.topic.add_moderator_post(moderator, I18n.t(message_key))
  end

  def moderator_already_replied?(topic, moderator)
    topic.posts.where("user_id = :user_id OR post_type = :post_type", user_id: moderator.id, post_type: Post.types[:moderator_action]).exists?
  end

  def self.create_message_for_post_action(user, post, post_action_type_id, opts)
    post_action_type = PostActionType.types[post_action_type_id]

    return unless opts[:message] && [:notify_moderators, :notify_user].include?(post_action_type)

    title = I18n.t("post_action_types.#{post_action_type}.email_title", title: post.topic.title)
    body = I18n.t("post_action_types.#{post_action_type}.email_body", message: opts[:message], link: "#{Discourse.base_url}#{post.url}")

    opts = {
      archetype: Archetype.private_message,
      title: title,
      raw: body
    }

    if post_action_type == :notify_moderators
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

  def self.act(user, post, post_action_type_id, opts = {})
    related_post_id = create_message_for_post_action(user, post, post_action_type_id, opts)
    staff_took_action = opts[:take_action] || false

    targets_topic = if opts[:flag_topic] && post.topic
                      post.topic.reload
                      post.topic.posts_count != 1
                    end

    where_attrs = {
      post_id: post.id,
      user_id: user.id,
      post_action_type_id: post_action_type_id
    }

    action_attributes = {
      staff_took_action: staff_took_action,
      related_post_id: related_post_id,
      targets_topic: !!targets_topic
    }

    # First try to revive a trashed record
    row_count = PostAction.where(where_attrs)
                          .with_deleted
                          .where("deleted_at IS NOT NULL")
                          .update_all(action_attributes.merge(deleted_at: nil))

    if row_count == 0
      post_action = create(where_attrs.merge(action_attributes))
      if post_action && post_action.errors.count == 0
        BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: post_action)
      end
    else
      post_action = PostAction.where(where_attrs).first

      # after_commit is not called on an `update_all` so do the notify ourselves
      post_action.notify_subscribers
    end

    # agree with other flags
    PostAction.agree_flags!(post, user) if staff_took_action
    # update counters
    post_action.try(:update_counters)

    post_action
  rescue ActiveRecord::RecordNotUnique
    # can happen despite being .create
    # since already bookmarked
    PostAction.where(where_attrs).first
  end

  def self.remove_act(user, post, post_action_type_id)
    finder = PostAction.where(post_id: post.id, user_id: user.id, post_action_type_id: post_action_type_id)
    finder = finder.with_deleted.includes(:post) if user.try(:staff?)
    if action = finder.first
      action.remove_act!(user)
      action.post.unhide! if action.staff_took_action
    end
  end

  def remove_act!(user)
    trash!(user)
    # NOTE: save is called to ensure all callbacks are called
    # trash will not trigger callbacks, and triggering after_commit
    # is not trivial
    save
  end

  def is_bookmark?
    post_action_type_id == PostActionType.types[:bookmark]
  end

  def is_like?
    post_action_type_id == PostActionType.types[:like]
  end

  def is_flag?
    PostActionType.flag_types.values.include?(post_action_type_id)
  end

  def is_private_message?
    post_action_type_id == PostActionType.types[:notify_user] ||
    post_action_type_id == PostActionType.types[:notify_moderators]
  end

  # A custom rate limiter for this model
  def post_action_rate_limiter
    return unless is_flag? || is_bookmark? || is_like?

    return @rate_limiter if @rate_limiter.present?

    %w(like flag bookmark).each do |type|
      if send("is_#{type}?")
        @rate_limiter = RateLimiter.new(user, "create_#{type}:#{Date.today}", SiteSetting.send("max_#{type}s_per_day"), 1.day.to_i)
        return @rate_limiter
      end
    end
  end

  before_create do
    post_action_type_ids = is_flag? ? PostActionType.flag_types.values : post_action_type_id
    raise AlreadyActed if PostAction.where(user_id: user_id)
                                    .where(post_id: post_id)
                                    .where(post_action_type_id: post_action_type_ids)
                                    .where(deleted_at: nil)
                                    .where(disagreed_at: nil)
                                    .where(targets_topic: targets_topic)
                                    .exists?
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
                            FROM post_actions AS pa
                              INNER JOIN users AS u ON u.id = pa.user_id
                            WHERE pa.post_id = :post_id
                              AND pa.post_action_type_id IN (:post_action_types)
                              AND pa.deleted_at IS NULL",
                            post_id: post_id,
                            post_action_types: PostActionType.auto_action_flag_types.values,
                            flags_required_to_hide_post: SiteSetting.flags_required_to_hide_post).first

    [flag_counts['old_flags'].to_i, flag_counts['new_flags'].to_i]
  end

  def post_action_type_key
    PostActionType.types[post_action_type_id]
  end

  def update_counters
    # Update denormalized counts
    column = "#{post_action_type_key}_count"
    count = PostAction.where(post_id: post_id)
                      .where(post_action_type_id: post_action_type_id)
                      .count

    # We probably want to refactor this method to something cleaner.
    case post_action_type_key
    when :vote
      # Voting also changes the sort_order
      Post.where(id: post_id).update_all ["vote_count = :count, sort_order = :max - :count", count: count, max: Topic.max_sort_order]
    when :like
      # `like_score` is weighted higher for staff accounts
      score = PostAction.joins(:user)
                        .where(post_id: post_id)
                        .sum("CASE WHEN users.moderator OR users.admin THEN #{SiteSetting.staff_like_weight} ELSE 1 END")
      Post.where(id: post_id).update_all ["like_count = :count, like_score = :score", count: count, score: score]
    else
      Post.where(id: post_id).update_all ["#{column} = ?", count]
    end

    topic_id = Post.with_deleted.where(id: post_id).pluck(:topic_id).first
    topic_count = Post.where(topic_id: topic_id).sum(column)
    Topic.where(id: topic_id).update_all ["#{column} = ?", topic_count]

    if PostActionType.notify_flag_type_ids.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

  end

  def enforce_rules
    post = Post.with_deleted.where(id: post_id).first
    PostAction.auto_hide_if_needed(user, post, post_action_type_key)
    SpamRulesEnforcer.enforce!(post.user) if post_action_type_key == :spam
  end

  def notify_subscribers
    if (is_like? || is_flag?) && post
      post.publish_change_to_clients! :acted
    end
  end

  def self.auto_hide_if_needed(acting_user, post, post_action_type)
    return if post.hidden

    if post_action_type == :spam &&
       acting_user.trust_level == TrustLevel[3] &&
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
      old_flags,_ = PostAction.flag_counts_for(post.id)
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

  def self.post_action_type_for_post(post_id)
    post_action = PostAction.find_by(deferred_at: nil, post_id: post_id, post_action_type_id: PostActionType.flag_types.values, deleted_at: nil)
    PostActionType.types[post_action.post_action_type_id]
  end

  def self.target_moderators
    Group[:moderators].name
  end

end

# == Schema Information
#
# Table name: post_actions
#
#  id                  :integer          not null, primary key
#  post_id             :integer          not null
#  user_id             :integer          not null
#  post_action_type_id :integer          not null
#  deleted_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  deleted_by_id       :integer
#  related_post_id     :integer
#  staff_took_action   :boolean          default(FALSE), not null
#  deferred_by_id      :integer
#  targets_topic       :boolean          default(FALSE), not null
#  agreed_at           :datetime
#  agreed_by_id        :integer
#  deferred_at         :datetime
#  disagreed_at        :datetime
#  disagreed_by_id     :integer
#
# Indexes
#
#  idx_unique_actions             (user_id,post_action_type_id,post_id,targets_topic) UNIQUE
#  index_post_actions_on_post_id  (post_id)
#
