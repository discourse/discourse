require_dependency 'rate_limiter'
require_dependency 'system_message'

class PostAction < ActiveRecord::Base
  class AlreadyFlagged < StandardError; end

  include RateLimiter::OnCreateRecord

  attr_accessible :post_action_type_id, :post_id, :user_id, :post, :user, :post_action_type, :message, :related_post_id

  belongs_to :post
  belongs_to :user
  belongs_to :post_action_type

  acts_as_paranoid

  rate_limit :post_action_rate_limiter

  validate :message_quality

  def self.update_flagged_posts_count
    posts_flagged_count = PostAction.joins(post: :topic)
                                    .where('post_actions.post_action_type_id' => PostActionType.notify_flag_types.values,
                                           'posts.deleted_at' => nil,
                                           'topics.deleted_at' => nil).count('DISTINCT posts.id')

    $redis.set('posts_flagged_count', posts_flagged_count)
    user_ids = User.staff.select(:id).map {|u| u.id}
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

    PostAction.update_all({ deleted_at: Time.zone.now, deleted_by: moderator_id }, { post_id: post.id, post_action_type_id: actions })

    f = actions.map{|t| ["#{PostActionType.types[t]}_count", 0]}

    Post.with_deleted.update_all(Hash[*f.flatten], id: post.id)

    update_flagged_posts_count
  end

  def self.act(user, post, post_action_type_id, message = nil)
    begin
      title, target_usernames, subtype, body = nil

      if message
        [:notify_moderators, :notify_user].each do |k|
          if post_action_type_id == PostActionType.types[k]
            target_usernames = k == :notify_moderators ? target_moderators(user) : post.user.username
            title = I18n.t("post_action_types.#{k}.email_title",
                            title: post.topic.title)
            body = I18n.t("post_action_types.#{k}.email_body",
                          message: message,
                          link: "#{Discourse.base_url}#{post.url}")
            subtype = k == :notify_moderators ? TopicSubtype.notify_moderators : TopicSubtype.notify_user
          end
        end
      end

      related_post_id = nil
      if target_usernames.present?
        related_post_id = PostCreator.new(user,
                              target_usernames: target_usernames,
                              archetype: Archetype.private_message,
                              subtype: subtype,
                              title: title,
                              raw: body
                       ).create.id
      end
      create( post_id: post.id,
              user_id: user.id,
              post_action_type_id: post_action_type_id,
              message: message,
              related_post_id: related_post_id )
    rescue ActiveRecord::RecordNotUnique
      # can happen despite being .create
      # since already bookmarked
      true
    end
  end

  def self.remove_act(user, post, post_action_type_id)
    if action = where(post_id: post.id, user_id: user.id, post_action_type_id: post_action_type_id).first
      action.destroy
      action.deleted_at = Time.zone.now
      action.run_callbacks(:save)
    end
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

  def message_quality
    return if message.blank?
    sentinel = TextSentinel.title_sentinel(message)
    errors.add(:message, I18n.t(:is_invalid)) unless sentinel.valid?
  end

  before_create do
    raise AlreadyFlagged if is_flag? && PostAction.where(user_id: user_id,
                                                         post_id: post_id,
                                                         post_action_type_id: PostActionType.flag_types.values).exists?
  end

  after_save do
    # Update denormalized counts
    post_action_type = PostActionType.types[post_action_type_id]
    column = "#{post_action_type.to_s}_count"
    delta = deleted_at.nil? ? 1 : -1

    # Voting also changes the sort_order
    if post_action_type == :vote
      Post.update_all ["vote_count = vote_count + :delta, sort_order = :max - (vote_count + :delta)", delta: delta, max: Topic.max_sort_order], id: post_id
    else
      Post.update_all ["#{column} = #{column} + ?", delta], id: post_id
    end
    Topic.update_all ["#{column} = #{column} + ?", delta], id: post.topic_id


    if PostActionType.notify_flag_types.values.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

    if PostActionType.auto_action_flag_types.include?(post_action_type) && SiteSetting.flags_required_to_hide_post > 0
      # automatic hiding of posts
      flag_counts = exec_sql("SELECT SUM(CASE WHEN deleted_at IS NULL THEN 1 ELSE 0 END) AS new_flags,
                                     SUM(CASE WHEN deleted_at IS NOT NULL THEN 1 ELSE 0 END) AS old_flags
                              FROM post_actions
                              WHERE post_id = ? AND post_action_type_id IN (?)", post.id, PostActionType.auto_action_flag_types.values).first
      old_flags, new_flags = flag_counts['old_flags'].to_i, flag_counts['new_flags'].to_i

      if new_flags >= SiteSetting.flags_required_to_hide_post
        reason = old_flags > 0 ? Post.hidden_reasons[:flag_threshold_reached_again] : Post.hidden_reasons[:flag_threshold_reached]
        Post.update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", reason], id: post_id)
        Topic.update_all({ visible: false },
                         ["id = :topic_id AND NOT EXISTS(SELECT 1 FROM POSTS WHERE topic_id = :topic_id AND NOT hidden)", topic_id: post.topic_id])

        # inform user
        if post.user
          SystemMessage.create(post.user, :post_hidden,
                               url: post.url,
                               edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts)
        end
      end
    end
  end

  protected

  def self.target_moderators(me)
    User
      .where("moderator = 't' or admin = 't'")
      .where('id <> ?', [me.id])
      .select('username')
      .map{|u| u.username}
      .join(',')
  end

end
