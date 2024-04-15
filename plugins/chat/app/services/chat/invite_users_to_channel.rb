# frozen_string_literal: true

module Chat
  # Invites users to a channel.
  #
  # @example
  #  Chat::InviteUsersToChannel.call(channel_id: 2, user_ids: [2, 43], guardian: guardian, **optional_params)
  #
  class InviteUsersToChannel
    include Service::Base

    # @!method call(user_ids:, channel_id:, guardian:)
    #   @param [Array<Integer>] user_ids
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @option optional_params [Integer, nil] message_id
    #   @return [Service::Base::Context]

    contract
    model :channel
    policy :can_view_channel
    model :users, optional: true
    step :send_invite_notifications

    # @!visibility private
    class Contract
      attribute :user_ids, :array
      validates :user_ids, presence: true

      attribute :channel_id, :integer
      validates :channel_id, presence: true

      attribute :message_id, :integer
    end

    private

    def fetch_channel(contract:)
      ::Chat::Channel.find_by(id: contract.channel_id)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_users(contract:)
      ::User
        .joins(:user_option)
        .where(user_options: { chat_enabled: true })
        .not_suspended
        .where(id: contract.user_ids)
        .limit(50)
    end

    def send_invite_notifications(channel:, guardian:, users:, contract:)
      users&.each do |invited_user|
        next if !invited_user.guardian.can_join_chat_channel?(channel)

        data = {
          message: "chat.invitation_notification",
          chat_channel_id: channel.id,
          chat_channel_title: channel.title(invited_user),
          chat_channel_slug: channel.slug,
          invited_by_username: guardian.user.username,
        }
        data[:chat_message_id] = contract.message_id if contract.message_id

        invited_user.notifications.create(
          notification_type: ::Notification.types[:chat_invitation],
          high_priority: true,
          data: data.to_json,
        )
      end
    end
  end
end
