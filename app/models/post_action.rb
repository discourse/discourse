require_dependency 'rate_limiter'
require_dependency 'system_message'
require_dependency 'trashable'

class PostAction < ActiveRecord::Base
  class AlreadyActed < StandardError; end

  include RateLimiter::OnCreateRecord
  include Trashable

  belongs_to :post
  belongs_to :user
  belongs_to :post_action_type
  belongs_to :related_post, class_name: 'Post'

  rate_limit :post_action_rate_limiter

  scope :spam_flags, -> { where(post_action_type_id: PostActionType.types[:spam]) }

  after_save :update_counters
  after_save :enforce_rules

  def self.update_flagged_posts_count
    posts_flagged_count = PostAction.joins(post: :topic)
                                    .where('defer = false or defer IS NULL')
                                    .where('post_actions.post_action_type_id' => PostActionType.notify_flag_type_ids,
                                           'posts.deleted_at' => nil,
                                           'topics.deleted_at' => nil)
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

    collection_ids = collection.map {|p| p.id}

    user_id = user.present? ? user.id : 0

    result = PostAction.where(post_id: collection_ids, user_id: user_id)
    user_actions = {}
    result.each do |r|
      user_actions[r.post_id] ||= {}
      user_actions[r.post_id][r.post_action_type_id] = r
    end

    user_actions
  end

  def self.count_per_day_for_type(sinceDaysAgo = 30, post_action_type)
    unscoped.where(post_action_type_id: post_action_type).where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def self.clear_flags!(post, moderator_id, action_type_id = nil)
    # -1 is the automatic system cleary
    actions = if action_type_id
      [action_type_id]
    else
      moderator_id == -1 ? PostActionType.auto_action_flag_types.values : PostActionType.flag_types.values
    end

    PostAction.where({ post_id: post.id, post_action_type_id: actions }).update_all({ deleted_at: Time.zone.now, deleted_by_id: moderator_id })
    f = actions.map{|t| ["#{PostActionType.types[t]}_count", 0]}
    Post.where(id: post.id).with_deleted.update_all(Hash[*f.flatten])
    update_flagged_posts_count
  end

  def self.defer_flags!(post, moderator_id)
    actions = PostAction.where(
      defer: nil,
      post_id: post.id,
      post_action_type_id:
      PostActionType.flag_types.values,
      deleted_at: nil
    )

    actions.each do |a|
      a.defer = true
      a.defer_by = moderator_id
      # so callback is called
      a.save
    end

    update_flagged_posts_count
  end

  def self.create_message_for_post_action(user, post, post_action_type_id, opts)
    post_action_type = PostActionType.types[post_action_type_id]

    return unless opts[:message] && [:notify_moderators, :notify_user].include?(post_action_type)

    # this is a hack to allow a PM with no reciepients, we should think through
    # a cleaner technique, a PM with myself is valid for flagging
    target_usernames = post_action_type == :notify_user ? post.user.username : "x"

    title = I18n.t("post_action_types.#{post_action_type}.email_title",
                    title: post.topic.title)
    body = I18n.t("post_action_types.#{post_action_type}.email_body",
                  message: opts[:message],
                  link: "#{Discourse.base_url}#{post.url}")

    subtype = post_action_type == :notify_moderators ? TopicSubtype.notify_moderators : TopicSubtype.notify_user

    if target_usernames.present?
      PostCreator.new(user,
              target_usernames: target_usernames,
              archetype: Archetype.private_message,
              subtype: subtype,
              title: title,
              raw: body
       ).create.id
    end
  end

  def self.act(user, post, post_action_type_id, opts={})

    related_post_id = create_message_for_post_action(user,post,post_action_type_id,opts)

    create( post_id: post.id,
            user_id: user.id,
            post_action_type_id: post_action_type_id,
            message: opts[:message],
            staff_took_action: opts[:take_action] || false,
            related_post_id: related_post_id )
  rescue ActiveRecord::RecordNotUnique
    # can happen despite being .create
    # since already bookmarked
    true
  end

  def self.remove_act(user, post, post_action_type_id)
    if action = where(post_id: post.id,
                      user_id: user.id,
                      post_action_type_id: post_action_type_id).first
      action.remove_act!(user)
    end
  end

  def remove_act!(user)
    trash!(user)
    run_callbacks(:save)
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
        @rate_limiter = RateLimiter.new(user, "create_#{type}:#{Date.today.to_s}", SiteSetting.send("max_#{type}s_per_day"), 1.day.to_i)
        return @rate_limiter
      end
    end
  end

  before_create do
    post_action_type_ids = is_flag? ? PostActionType.flag_types.values : post_action_type_id
    raise AlreadyActed if PostAction.where(user_id: user_id,
                                           post_id: post_id,
                                           post_action_type_id: post_action_type_ids,
                                           deleted_at: nil)
                                    .exists?
  end

  # Returns the flag counts for a post, taking into account that some users
  # can weigh flags differently.
  def self.flag_counts_for(post_id)
    flag_counts = exec_sql("SELECT SUM(CASE
                                         WHEN pa.deleted_at IS NULL AND (pa.staff_took_action) THEN :flags_required_to_hide_post
                                         WHEN pa.deleted_at IS NULL AND (NOT pa.staff_took_action) THEN 1
                                         ELSE 0
                                       END) AS new_flags,
                                   SUM(CASE
                                         WHEN pa.deleted_at IS NOT NULL AND (pa.staff_took_action) THEN :flags_required_to_hide_post
                                         WHEN pa.deleted_at IS NOT NULL AND (NOT pa.staff_took_action) THEN 1
                                         ELSE 0
                                       END) AS old_flags
                            FROM post_actions AS pa
                              INNER JOIN users AS u ON u.id = pa.user_id
                            WHERE pa.post_id = :post_id AND
                              pa.post_action_type_id IN (:post_action_types)",
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
    column = "#{post_action_type_key.to_s}_count"
    delta = deleted_at.nil? ? 1 : -1

    # We probably want to refactor this method to something cleaner.
    case post_action_type_key
    when :vote
      # Voting also changes the sort_order
      Post.where(id: post_id).update_all ["vote_count = vote_count + :delta, sort_order = :max - (vote_count + :delta)",
                        delta: delta,
                        max: Topic.max_sort_order]
    when :like
      # `like_score` is weighted higher for staff accounts
      Post.where(id: post_id).update_all ["like_count = like_count + :delta, like_score = like_score + :score_delta",
                        delta: delta,
                        score_delta: user.staff? ? delta * SiteSetting.staff_like_weight : delta]
    else
      Post.where(id: post_id).update_all ["#{column} = #{column} + ?", delta]
    end

    Topic.where(id: post.topic_id).update_all ["#{column} = #{column} + ?", delta]


    if PostActionType.notify_flag_type_ids.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

  end

  def enforce_rules
    PostAction.auto_hide_if_needed(post, post_action_type_key)
    SpamRulesEnforcer.enforce!(post.user) if post_action_type_key == :spam
  end

  def self.auto_hide_if_needed(post, post_action_type)
    return if post.hidden

    if PostActionType.auto_action_flag_types.include?(post_action_type) &&
       SiteSetting.flags_required_to_hide_post > 0

      old_flags, new_flags = PostAction.flag_counts_for(post.id)

      if new_flags >= SiteSetting.flags_required_to_hide_post
        hide_post!(post, guess_hide_reason(old_flags))
      end
    end
  end


  def self.hide_post!(post, reason=nil)
    return if post.hidden

    unless reason
      old_flags,_ = PostAction.flag_counts_for(post.id)
      reason = guess_hide_reason(old_flags)
    end

    Post.where(id: post.id).update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", reason])
    Topic.where(["id = :topic_id AND NOT EXISTS(SELECT 1 FROM POSTS WHERE topic_id = :topic_id AND NOT hidden)",
                      topic_id: post.topic_id]).update_all({ visible: false })

    # inform user
    if post.user
      SystemMessage.create(post.user,
                           :post_hidden,
                           url: post.url,
                           edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts)
    end
  end

  def self.guess_hide_reason(old_flags)
    old_flags > 0 ?
      Post.hidden_reasons[:flag_threshold_reached_again] :
      Post.hidden_reasons[:flag_threshold_reached]
  end

  protected

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
#  message             :text
#  related_post_id     :integer
#  staff_took_action   :boolean          default(FALSE), not null
#  defer               :boolean
#  defer_by            :integer
#
# Indexes
#
#  idx_unique_actions             (user_id,post_action_type_id,post_id,deleted_at) UNIQUE
#  index_post_actions_on_post_id  (post_id)
#

