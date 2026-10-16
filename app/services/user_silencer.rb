# frozen_string_literal: true

class UserSilencer
  attr_reader :user_history

  def initialize(user, by_user = nil, opts = {})
    @user, @by_user, @opts = user, by_user, opts
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
    return false if @user.staff?
    hide_posts unless @opts[:keep_posts]
    return false if @user.silenced?
    @user.silenced_till = @opts[:silenced_till] || 1000.years.from_now
    if @user.save
      message_type = @opts[:message] || :silenced_by_staff

      details = StaffMessageFormat.new(:silence, @opts[:reason], @opts[:message_body]).format

      context = "#{message_type}: #{@opts[:reason]}"

      if @by_user
        log_params = { context: context, details: details, reviewable_id: @opts[:reviewable_id] }
        log_params[:post_id] = @opts[:post_id].to_i if @opts[:post_id]

        @user_history = StaffActionLogger.new(@by_user).log_silence_user(@user, log_params)
      end

      silence_message_params =
        if message_type.to_s == "silenced_by_staff"
          { silence_notice: silence_notice }
        else
          {}
        end
      silence_message_params[:notification_context] = @opts[:notification_context] if @opts[
        :notification_context
      ]
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
    unless topic_ids.empty?
      Topic.where(id: topic_ids).update_all(visible: false)
      CategoryFeaturedTopic.where(topic_id: topic_ids).delete_all
    end
  end

  def unsilence
    return false if @user.silenced_till.blank?

    @user.silenced_till = nil
    if @user.save
      DiscourseEvent.trigger(:user_unsilenced, user: @user, by_user: @by_user)
      SystemMessage.create(@user, :unsilenced)
      if @by_user
        StaffActionLogger.new(@by_user).log_unsilence_user(
          @user,
          reviewable_id: @opts[:reviewable_id],
        )
      end
    end
  end

  private

  def silence_notice
    locale = @user.effective_locale
    if @user.silenced_till > 100.years.from_now
      I18n.t("system_messages.silenced_by_staff.silenced_indefinitely", locale:)
    else
      timezone =
        ActiveSupport::TimeZone[@user.user_option.timezone.presence || "UTC"] ||
          ActiveSupport::TimeZone["UTC"]
      local_date = @user.silenced_till.in_time_zone(timezone)
      I18n.t(
        "system_messages.silenced_by_staff.silenced_until",
        locale:,
        date: I18n.l(local_date, format: :long, locale:),
        offset: local_date.formatted_offset,
      )
    end
  end

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
