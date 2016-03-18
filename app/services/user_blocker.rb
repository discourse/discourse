class UserBlocker

  def initialize(user, by_user=nil, opts={})
    @user, @by_user, @opts = user, by_user, opts
  end

  def self.block(user, by_user=nil, opts={})
    UserBlocker.new(user, by_user, opts).block
  end

  def self.unblock(user, by_user=nil, opts={})
    UserBlocker.new(user, by_user, opts).unblock
  end

  def block
    hide_posts unless @opts[:keep_posts]
    unless @user.blocked?
      @user.blocked = true
      if @user.save
        SystemMessage.create(@user, @opts[:message] || :blocked_by_staff)
        StaffActionLogger.new(@by_user).log_block_user(@user) if @by_user
      end
    else
      false
    end
  end

  def hide_posts
    Post.where(user_id: @user.id).update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", Post.hidden_reasons[:new_user_spam_threshold_reached]])
    topic_ids = Post.where(user_id: @user.id, post_number: 1).pluck(:topic_id)
    Topic.where(id: topic_ids).update_all(visible: false) unless topic_ids.empty?
  end

  def unblock
    @user.blocked = false
    if @user.save
      SystemMessage.create(@user, :unblocked)
      StaffActionLogger.new(@by_user).log_unblock_user(@user) if @by_user
    end
  end

end
