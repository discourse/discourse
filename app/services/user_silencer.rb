class UserSilencer

  attr_reader :user_history

  def initialize(user, by_user = nil, opts = {})
    @user, @by_user, @opts = user, by_user, opts
  end

  def self.silence(user, by_user = nil, opts = {})
    UserSilencer.new(user, by_user, opts).silence
  end

  def self.unsilence(user, by_user = nil, opts = {})
    UserSilencer.new(user, by_user, opts).unsilence
  end

  def silence
    hide_posts unless @opts[:keep_posts]
    unless @user.silenced_till.present?
      @user.silenced_till = @opts[:silenced_till] || 1000.years.from_now
      if @user.save
        message_type = @opts[:message] || :silenced_by_staff

        if @opts[:context].present?
          context = @opts[:context]
        else
          context = "#{message_type}: '#{post.topic&.title rescue ''}' #{@opts[:reason]}"
          SystemMessage.create(@user, message_type)
        end

        if @by_user
          @user_history = StaffActionLogger.new(@by_user).log_silence_user(
            @user,
            context: context,
            details: @opts[:reason]
          )
        end
        return true
      end
    else
      false
    end
  end

  def hide_posts
    return unless @user.trust_level == TrustLevel[0]

    Post.where(user_id: @user.id).where("created_at > ?", 24.hours.ago).update_all(["hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)", Post.hidden_reasons[:new_user_spam_threshold_reached]])
    topic_ids = Post.where(user_id: @user.id, post_number: 1).where("created_at > ?", 24.hours.ago).pluck(:topic_id)
    Topic.where(id: topic_ids).update_all(visible: false) unless topic_ids.empty?
  end

  def unsilence
    @user.silenced_till = nil
    if @user.save
      SystemMessage.create(@user, :unsilenced)
      StaffActionLogger.new(@by_user).log_unsilence_user(@user) if @by_user
    end
  end

end
