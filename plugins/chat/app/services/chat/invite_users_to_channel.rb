# frozen_string_literal: true

module Chat
  # Invites users to a channel.
  #
  # @example
  #  Chat::InviteUsersToChannel.call(params: { channel_id: 2, user_ids: [2, 43] }, guardian: guardian)
  #
  class InviteUsersToChannel
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Array<Integer>] :user_ids
    #   @option params [Integer] :channel_id
    #   @option params [Integer, nil] :message_id
    #   @return [Service::Base::Context]

    params do
      attribute :user_ids, :array
      attribute :channel_id, :integer
      attribute :message_id, :integer

      validates :user_ids, presence: true
      validates :channel_id, presence: true
    end
    model :channel
    policy :can_view_channel
    model :users, optional: true
    step :send_invite_notifications

    private

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params[:channel_id])
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_users(params:)
      ::User
        .joins(:user_option)
        .where(user_options: { chat_enabled: true })
        .not_suspended
        .where(id: params[:user_ids])
        .limit(50)
    end

    def send_invite_notifications(channel:, guardian:, users:, params:)
      users&.each do |invited_user|
        next if !invited_user.guardian.can_join_chat_channel?(channel)

        data = {
          message: "chat.invitation_notification",
          chat_channel_id: channel.id,
          chat_channel_title: channel.title(invited_user),
          chat_channel_slug: channel.slug,
          invited_by_username: guardian.user.username,
          chat_message_id: params[:message_id],
        }.compact

        invited_user.notifications.create(
          notification_type: ::Notification.types[:chat_invitation],
          high_priority: true,
          data: data.to_json,
        )
      end
    end
  end
end
