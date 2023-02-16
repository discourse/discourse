# frozen_string_literal: true

class Chat::ChatMessageRateLimiter
  def self.run!(user)
    instance = self.new(user)
    instance.run!
  end

  def initialize(user)
    @user = user
  end

  def run!
    return if @user.staff?

    allowed_message_count =
      (
        if @user.trust_level == TrustLevel[0]
          SiteSetting.chat_allowed_messages_for_trust_level_0
        else
          SiteSetting.chat_allowed_messages_for_other_trust_levels
        end
      )
    return if allowed_message_count.zero?

    @rate_limiter = RateLimiter.new(@user, "create_chat_message", allowed_message_count, 30.seconds)
    silence_user if @rate_limiter.remaining.zero?
    @rate_limiter.performed!
  end

  def clear!
    # Used only for testing. Need to clear the rate limiter between tests.
    @rate_limiter.clear! if defined?(@rate_limiter)
  end

  private

  def silence_user
    silenced_for_minutes = SiteSetting.chat_auto_silence_duration
    return if silenced_for_minutes.zero?

    UserSilencer.silence(
      @user,
      Discourse.system_user,
      silenced_till: silenced_for_minutes.minutes.from_now,
      reason: I18n.t("chat.errors.rate_limit_exceeded"),
    )
  end
end
