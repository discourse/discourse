# frozen_string_literal: true

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

  def self.was_silenced_for?(post)
    return false if post.blank?

    UserHistory.where(action: UserHistory.actions[:silence_user], post: post).exists?
  end

  def silence
    hide_posts unless @opts[:keep_posts]
    return false if @user.silenced_till.present?
    @user.silenced_till = @opts[:silenced_till] || 1000.years.from_now
    if @user.save
      message_type = @opts[:message] || :silenced_by_staff

      details = StaffMessageFormat.new(:silence, @opts[:reason], @opts[:message_body]).format

      context = "#{message_type}: #{@opts[:reason]}"

      if @by_user
        log_params = { context: context, details: details }
        log_params[:post_id] = @opts[:post_id].to_i if @opts[:post_id]

        @user_history = StaffActionLogger.new(@by_user).log_silence_user(@user, log_params)
      end

      silence_message_params = {}
      DiscourseEvent.trigger(
        :user_silenced,
        user: @user,
        silenced_by: @by_user,
        reason: @opts[:reason],
        message: @opts[:message_body],
        user_history: @user_history,
        post_id: @opts[:post_id],
        silenced_till: @user.silenced_till,
        silenced_at: DateTime.now,
        silence_message_params: silence_message_params,
      )

      silence_message_params.merge!(post_alert_options: { skip_send_email: true })
      SystemMessage.create(@user, message_type, silence_message_params)
      true
    end
  end

  def hide_posts
    return unless @user.trust_level == TrustLevel[0]

    Post
      .where(user_id: @user.id)
      .where("created_at > ?", 24.hours.ago)
      .update_all(
        [
          "hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)",
          Post.hidden_reasons[:new_user_spam_threshold_reached],
        ],
      )
    topic_ids =
      Post
        .where(user_id: @user.id, post_number: 1)
        .where("created_at > ?", 24.hours.ago)
        .pluck(:topic_id)
    Topic.where(id: topic_ids).update_all(visible: false) unless topic_ids.empty?
  end

  def unsilence
    @user.silenced_till = nil
    if @user.save
      DiscourseEvent.trigger(:user_unsilenced, user: @user, by_user: @by_user)
      SystemMessage.create(@user, :unsilenced)
      StaffActionLogger.new(@by_user).log_unsilence_user(@user) if @by_user
    end
  end
end
