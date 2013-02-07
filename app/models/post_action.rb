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
    val = exec_sql('select count(*) from posts p
                    join topics t on t.id = p.topic_id
                    where p.deleted_at is null and t.deleted_at is null and p.id in
                      (select post_id from post_actions where post_action_type_id in (?) and deleted_at is null)', PostActionType.FlagTypes).values[0][0].to_i
    $redis.set('posts_flagged_count', val)

    admins = User.exec_sql("select id from users where admin = 't'").map{|r| r["id"].to_i}
    MessageBus.publish('/flagged_counts', {total: val}, {user_ids: admins})
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

    PostAction.exec_sql('update post_actions set deleted_at = ?, deleted_by = ?
                           where post_id = ? and deleted_at is null and post_action_type_id in (?)',
                         DateTime.now, moderator_id, post.id, actions
                   )

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
    if is_flag?
      if PostAction.where('user_id = ? and post_id = ? and post_action_type_id in (?) and deleted_at is null',
                          self.user_id, self.post_id, PostActionType.FlagTypes).exists?
        raise AlreadyFlagged
      end
    end
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
      Post.update_all ["#{column} = #{column} + ?", delta], ["id = ?", post_id]
    end

    exec_sql "UPDATE topics SET #{column} = #{column} + ? WHERE id = (select p.topic_id from posts p where p.id = ?)", delta, post_id

    if PostActionType.FlagTypes.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

    if SiteSetting.flags_required_to_hide_post > 0
    # automatic hiding of posts
      info = exec_sql("select case when deleted_at is null then 'new' else 'old' end, count(*) from post_actions
                        where post_id = ? and
                        post_action_type_id in (?)
                        group by case when deleted_at is null then 'new' else 'old' end
                      ", self.post_id, PostActionType.AutoActionFlagTypes).values

      old_flags = new_flags = 0
      info.each do |r,v|
        old_flags = v.to_i if r == 'old'
        new_flags = v.to_i if r == 'new'
      end


      if new_flags >= SiteSetting.flags_required_to_hide_post
        exec_sql("update posts set hidden = ?, hidden_reason_id = coalesce(hidden_reason_id, ?) where id = ?",
                  true, old_flags > 0 ? Post::HiddenReason::FLAG_THRESHOLD_REACHED_AGAIN : Post::HiddenReason::FLAG_THRESHOLD_REACHED, self.post_id)

        exec_sql("update topics set visible = 'f'
                 where id = ? and not exists (select 1 from posts where hidden = 'f' and topic_id = ?)", self.post.topic_id, self.post.topic_id)

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
