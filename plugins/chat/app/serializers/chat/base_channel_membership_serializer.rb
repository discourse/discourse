# frozen_string_literal: true

module Chat
  class BaseChannelMembershipSerializer < ApplicationSerializer
    attributes :following,
               :muted,
               :notification_level,
               :chat_channel_id,
               :last_read_message_id,
               :last_viewed_at,
               :last_viewed_pins_at,
               :starred,
               :has_unseen_pins

    def starred
      object.starred
    end

    def include_starred?
      scope&.authenticated?
    end

    def has_unseen_pins
      object.has_unseen_pins?
    end

    def include_has_unseen_pins?
      SiteSetting.chat_pinned_messages && scope&.authenticated?
    end

    def include_last_viewed_pins_at?
      SiteSetting.chat_pinned_messages && scope&.authenticated?
    end
  end
end
