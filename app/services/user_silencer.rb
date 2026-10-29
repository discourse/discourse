# frozen_string_literal: true

class UserSilencer
  HIDE_RECENT_POSTS_SQL = <<~SQL
    UPDATE posts
    SET hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, :reason)
    WHERE user_id = :user_id AND created_at > :since AND deleted_at IS NULL AND NOT hidden
    RETURNING id
  SQL

  attr_reader :user_history

  def initialize(user, by_user = nil, opts = {})
    @user, @by_user, @opts = user, by_user, opts
    # An anonymous shadow reads its silence from the account behind it (User#silenced_till),
    # but everything reported keeps naming the shadow so it cannot unmask that account.
    @account = user.main_user_record
  end

  def self.silence(user, by_user = nil, opts = {})
    UserSilencer.new(user, by_user, opts).silence
  end

  def self.auto_silence(user, by_user = nil, opts = {})
    UserSilencer.new(user, by_user, opts).auto_silence
  end

  def self.unsilence(user, by_user = nil, opts = {})
    UserSilencer.new(user, by_user, opts).unsilence
  end

  def self.was_silenced_for?(post)
    return false if post.blank?

    UserHistory.where(action: UserHistory.actions[:silence_user], post: post).exists?
  end

  def silence
    return false if @account.staff?
    hide_posts unless @opts[:keep_posts]
    return false if @account.silenced?
    @account.silenced_till = @opts[:silenced_till] || 1000.years.from_now
    if @account.save
      message_type = @opts[:message] || :silenced_by_staff

      details = StaffMessageFormat.new(:silence, @opts[:reason], @opts[:message_body]).format

      context = "#{message_type}: #{@opts[:reason]}"

      if @by_user
        log_params = { context: context, details: details, reviewable_id: @opts[:reviewable_id] }
        log_params[:post_id] = @opts[:post_id].to_i if @opts[:post_id]

        @user_history = StaffActionLogger.new(@by_user).log_silence_user(@user, log_params)
      end

      silence_message_params = Dsa::AppealInstructions.message_options
      DiscourseEvent.trigger(
        :user_silenced,
        user: @user,
        silenced_by: @by_user,
        reason: @opts[:reason],
        message: @opts[:message_body],
        user_history: @user_history,
        post_id: @opts[:post_id],
        silenced_till: @account.silenced_till,
        silenced_at: DateTime.now,
        silence_message_params: silence_message_params,
      )

      silence_message_params.merge!(post_alert_options: { skip_send_email: true })
      SystemMessage.create(@user, message_type, silence_message_params)
      true
    end
  end

  def auto_silence
    if silence
      notify_moderators
      true
    else
      false
    end
  end

  def hide_posts
    return unless @user.trust_level == TrustLevel[0]

    hidden_post_ids =
      DB.query_single(
        HIDE_RECENT_POSTS_SQL,
        user_id: @user.id,
        since: 24.hours.ago,
        reason: Post.hidden_reasons[:new_user_spam_threshold_reached],
      )
    topic_ids =
      Post
        .where(user_id: @user.id, post_number: 1)
        .where("created_at > ?", 24.hours.ago)
        .pluck(:topic_id)
    acting_user = @by_user || Discourse.system_user

    unless topic_ids.empty?
      unlisted_topic_ids =
        DB.query_single(
          "UPDATE topics SET visible = false WHERE id IN (:topic_ids) AND visible RETURNING id",
          topic_ids:,
        )
      CategoryFeaturedTopic.where(topic_id: topic_ids).delete_all

      Topic
        .where(id: unlisted_topic_ids)
        .each do |topic|
          DB.after_commit do
            DiscourseEvent.trigger(:topic_status_updated, topic, "visible", false, acting_user:)
          end
        end
    end

    Post
      .where(id: hidden_post_ids)
      .includes(:topic)
      .each do |post|
        DB.after_commit do
          DiscourseEvent.trigger(:post_hidden, post, acting_user:, post_action_type_id: nil)
        end
      end
  end

  def unsilence
    unsilenced =
      @account.with_lock do
        next false if @account.silenced_till.blank?
        # The expiry job's batch can be stale: staff may have silenced the user again since.
        next false if @opts[:expired_only] && @account.silenced_till > Time.zone.now
        @account.update(silenced_till: nil)
      end
    return false if !unsilenced

    DiscourseEvent.trigger(:user_unsilenced, user: @user, by_user: @by_user)
    SystemMessage.create(@user, :unsilenced, Dsa::AppealInstructions.message_options)
    if @by_user
      StaffActionLogger.new(@by_user).log_unsilence_user(
        @user,
        reviewable_id: @opts[:reviewable_id],
      )
    end

    true
  end

  private

  def notify_moderators
    return if !SiteSetting.notify_mods_when_user_silenced

    GroupMessage.create(
      Group[:moderators].name,
      @opts[:reason] ? :user_automatically_silenced_with_reason : :user_automatically_silenced,
      user: @user,
      limit_once_per: false,
      message_params: {
        reason: @opts[:reason],
      },
    )
  end
end
