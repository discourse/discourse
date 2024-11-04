# frozen_string_literal: true

class Chat::Channel::Policy::MessageCreation < Service::PolicyBase
  class DirectMessageStrategy
    class << self
      def call(guardian, channel)
        guardian.can_create_channel_message?(channel) || guardian.can_create_direct_message?
      end

      def reason(*)
        I18n.t("chat.errors.user_cannot_send_direct_messages")
      end
    end
  end

  class CategoryStrategy
    class << self
      def call(guardian, channel)
        guardian.can_create_channel_message?(channel)
      end

      def reason(_, channel)
        I18n.t("chat.errors.channel_new_message_disallowed.#{channel.status}")
      end
    end
  end

  attr_reader :strategy

  delegate :channel, to: :context

  def initialize(*)
    super
    @strategy = CategoryStrategy
    @strategy = DirectMessageStrategy if channel.direct_message_channel?
  end

  def call
    strategy.call(guardian, channel)
  end

  def reason
    strategy.reason(guardian, channel)
  end
end
