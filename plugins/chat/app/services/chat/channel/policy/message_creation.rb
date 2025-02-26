# frozen_string_literal: true

class Chat::Channel::Policy::MessageCreation < Service::PolicyBase
  class Strategy
    extend Dry::Initializer

    param :guardian
    param :channel
  end

  class DirectMessageStrategy < Strategy
    delegate :username, to: :target, allow_nil: true, private: true

    def call
      if !guardian.can_create_channel_message?(channel) ||
           !guardian.can_send_direct_message?(channel) || !guardian.allowing_direct_messages?
        return false
      end
      if solo_chat? || channel.chatable.group? || guardian.user.is_system_user? ||
           guardian.user.bot?
        return true
      end

      target.present? && guardian.recipient_not_muted?(target) &&
        guardian.recipient_not_ignored?(target) && guardian.recipient_can_chat?(target) &&
        guardian.recipient_allows_direct_messages?(target)
    end

    def reason
      if !guardian.can_create_channel_message?(channel)
        I18n.t("chat.errors.channel_new_message_disallowed.closed")
      elsif !guardian.can_send_direct_message?(channel)
        I18n.t("chat.errors.user_cannot_send_direct_messages")
      elsif !guardian.allowing_direct_messages?
        I18n.t("chat.errors.actor_disallowed_dms")
      elsif target.blank?
        I18n.t("chat.errors.user_cannot_send_direct_messages")
      elsif !guardian.recipient_not_muted?(target)
        I18n.t("chat.errors.actor_muting_target_user", username:)
      elsif !guardian.recipient_not_ignored?(target)
        I18n.t("chat.errors.actor_ignoring_target_user", username:)
      elsif !guardian.recipient_can_chat?(target)
        I18n.t("chat.errors.not_reachable", username:)
      elsif !guardian.recipient_allows_direct_messages?(target)
        I18n.t("chat.errors.not_accepting_dms", username:)
      else
        I18n.t("chat.errors.user_cannot_send_direct_messages")
      end
    end

    private

    def target
      @target ||= channel.chatable.users.reject { |u| u.id == guardian.user.id }.first
    end

    def solo_chat?
      @solo_chat ||= channel.chatable.users.size === 1
    end
  end

  class CategoryStrategy < Strategy
    def call
      guardian.can_create_channel_message?(channel)
    end

    def reason
      I18n.t("chat.errors.channel_new_message_disallowed.#{channel.status}")
    end
  end

  attr_reader :strategy

  delegate :channel, to: :context

  def initialize(*)
    super
    @strategy = CategoryStrategy
    @strategy = DirectMessageStrategy if channel.direct_message_channel?
    @strategy = @strategy.new(guardian, channel)
  end

  def call
    strategy.call
  end

  def reason
    strategy.reason
  end
end
