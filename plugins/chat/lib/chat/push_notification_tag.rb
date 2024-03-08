# frozen_string_literal: true

module Chat
  class PushNotificationTag
    def self.for_mention(channel_id)
      tag("chat-mention", channel_id)
    end

    def self.for_message(channel_id)
      tag("chat-message", channel_id)
    end

    private

    def self.tag(type, channel_id)
      "#{Discourse.current_hostname}-#{type}-#{channel_id}"
    end

    private_class_method :tag
  end
end
