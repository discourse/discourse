# frozen_string_literal: true

module Chat
  class BaseChannelMembershipSerializer < ApplicationSerializer
    attributes :following,
               :muted,
               :notification_level,
               :chat_channel_id,
               :last_read_message_id,
               :last_viewed_at,
               :starred

    def starred
      if scope.user&.upcoming_change_enabled?(:star_chat_channels)
        object.starred
      else
        false
      end
    end

    def include_starred?
      true
    end
  end
end
