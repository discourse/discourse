require_dependency 'rate_limiter'
require_dependency 'system_message'

class PostAction < ActiveRecord::Base
  class AlreadyFlagged < StandardError; end

  include RateLimiter::OnCreateRecord

  attr_accessible :deleted_at, :post_action_type_id, :post_id, :user_id, :post, :user, :post_action_type, :message

  belongs_to :post
  belongs_to :user
  belongs_to :post_action_type

  rate_limit :post_action_rate_limiter

  def self.update_flagged_posts_count

    posts_flagged_count = PostAction.joins(post: :topic)
                                    .where('post_actions.post_action_type_id' => PostActionType.FlagTypes, 
                                           'post_actions.deleted_at' => nil,
                                           'posts.deleted_at' => nil,
                                           'topics.deleted_at' => nil).count('DISTINCT posts.id')

    $redis.set('posts_flagged_count', posts_flagged_count)
    admins = User.where(admin: true).select(:id).map {|u| u.id}
    MessageBus.publish('/flagged_counts', {total: posts_flagged_count}, {user_ids: admins})
  end

  def self.flagged_posts_count
    $redis.get('posts_flagged_count').to_i
  end

  def self.counts_for(collection, user)

  	return {} if collection.blank?

    collection_ids = collection.map {|p| p.id}

    user_id = user.present? ? user.id : 0

    result = PostAction.where(post_id: collection_ids, user_id: user_id, deleted_at: nil)
    user_actions = {}
    result.each do |r|
      user_actions[r.post_id] ||= {}
      user_actions[r.post_id][r.post_action_type_id] = r
    end

    user_actions
  end

  def self.clear_flags!(post, moderator_id, action_type_id = nil)

    # -1 is the automatic system cleary
    actions = if action_type_id
      [action_type_id]
    else
      moderator_id == -1 ? PostActionType.AutoActionFlagTypes : PostActionType.FlagTypes
    end

    PostAction.update_all({deleted_at: Time.now, deleted_by: moderator_id}, {post_id: post.id, deleted_at: nil, post_action_type_id: actions})

    r = PostActionType.Types.invert
    f = actions.map{|t| ["#{r[t]}_count", 0]}

    Post.update_all(Hash[*f.flatten], id: post.id)

    update_flagged_posts_count
  end

  def self.act(user, post, post_action_type_id, message = nil)
    begin
      create(post_id: post.id, user_id: user.id, post_action_type_id: post_action_type_id, message: message)
    rescue ActiveRecord::RecordNotUnique
      # can happen despite being .create
      # since already bookmarked
      true
    end
  end

  def self.remove_act(user, post, post_action_type_id)
    if action = self.where(post_id: post.id, user_id: user.id, post_action_type_id: post_action_type_id, deleted_at: nil).first

      transaction do
        d = DateTime.now
        count = PostAction.update_all({deleted_at: d},{id: action.id, deleted_at: nil})

        if(count == 1)
          action.deleted_at = DateTime.now
          action.run_callbacks(:save)
          action.run_callbacks(:destroy)
        end
      end
    end
  end

  def is_bookmark?
    post_action_type_id == PostActionType.Types[:bookmark]
  end

  def is_like?
    post_action_type_id == PostActionType.Types[:like]
  end

  def is_flag?
    PostActionType.FlagTypes.include?(post_action_type_id)
  end

  # A custom rate limiter for this model
  def post_action_rate_limiter
    return nil unless is_flag? or is_bookmark? or is_like?

    return @rate_limiter if @rate_limiter.present?

    %w(like flag bookmark).each do |type|
      if send("is_#{type}?")
        @rate_limiter = RateLimiter.new(user, "create_#{type}:#{Date.today.to_s}", SiteSetting.send("max_#{type}s_per_day"), 1.day.to_i)
        return @rate_limiter
      end
    end
  end

  before_create do
    raise AlreadyFlagged if is_flag? and PostAction.where(user_id: user_id, 
                                                          post_id: post_id, 
                                                          post_action_type_id: PostActionType.FlagTypes, 
                                                          deleted_at: nil).exists?    
  end

  after_save do

    # Update denormalized counts
    post_action_type = PostActionType.Types.invert[post_action_type_id]
    column = "#{post_action_type.to_s}_count"
    delta = deleted_at.nil? ? 1 : -1

    # Voting also changes the sort_order
    if post_action_type == :vote
      Post.update_all ["vote_count = vote_count + :delta, sort_order = :max - (vote_count + :delta)", delta: delta, max: Topic::MAX_SORT_ORDER], ["id = ?", post_id]
    else
      Post.update_all ["#{column} = #{column} + ?", delta], id: post_id
    end
    Topic.update_all ["#{column} = #{column} + ?", delta], id: post.topic_id


    if PostActionType.FlagTypes.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

    if SiteSetting.flags_required_to_hide_post > 0
      # automatic hiding of posts
      flag_counts = exec_sql("SELECT SUM(CASE WHEN deleted_at IS NULL THEN 1 ELSE 0 END) AS new_flags,
                                     SUM(CASE WHEN deleted_at IS NOT NULL THEN 1 ELSE 0 END) AS old_flags
                              FROM post_actions
                              WHERE post_id = ? AND post_action_type_id IN (?)", post.id, PostActionType.AutoActionFlagTypes).first
      old_flags, new_flags = flag_counts['old_flags'].to_i, flag_counts['new_flags'].to_i

      if new_flags >= SiteSetting.flags_required_to_hide_post
        reason = old_flags > 0 ? Post::HiddenReason::FLAG_THRESHOLD_REACHED_AGAIN : Post::HiddenReason::FLAG_THRESHOLD_REACHED
        Post.update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", reason], id: post_id)
        Topic.update_all({visible: false},
                         ["id = :topic_id AND NOT EXISTS(SELECT 1 FROM POSTS WHERE topic_id = :topic_id AND NOT hidden)", topic_id: post.topic_id])

        # inform user
        if self.post.user
          SystemMessage.create(self.post.user, :post_hidden, 
                               url: self.post.url, 
                               edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts)
        end
      end

    end

  end
end
