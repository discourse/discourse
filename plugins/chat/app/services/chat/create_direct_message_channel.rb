# frozen_string_literal: true

module Chat
  # Service responsible for creating a new direct message chat channel.
  # The guardian passed in is the "acting user" when creating the channel
  # and deciding whether the actor can communicate with the users that
  # are passed in.
  #
  # @example
  #  Service::Chat::CreateDirectMessageChannel.call(
  #    guardian: guardian,
  #    target_usernames: ["bob", "alice"]
  #  )
  #
  class CreateDirectMessageChannel
    include Service::Base

    # @!method call(guardian:, **params_to_create)
    #   @param [Guardian] guardian
    #   @param [Hash] params_to_create
    #   @option params_to_create [Array<String>] target_usernames
    #   @return [Service::Base::Context]

    policy :can_create_direct_message
    contract
    model :target_users
    policy :does_not_exceed_max_direct_message_users,
           class_name: Chat::DirectMessageChannel::MaxUsersExcessPolicy
    model :user_comm_screener
    policy :acting_user_not_disallowing_all_messages
    policy :acting_user_can_message_all_target_users,
           class_name: Chat::DirectMessageChannel::CanMessageAllTargetUsersPolicy
    policy :acting_user_not_preventing_messages_from_any_target_users,
           class_name: Chat::DirectMessageChannel::NotPreventingMessagesFromAnyTargetUsersPolicy
    policy :acting_user_not_ignoring_any_target_users,
           class_name: Chat::DirectMessageChannel::NotIgnoringAnyTargetUsersPolicy
    policy :acting_user_not_muting_any_target_users,
           class_name: Chat::DirectMessageChannel::NotMutingAnyTargetUsersPolicy
    model :direct_message, :fetch_or_create_direct_message
    model :channel, :fetch_or_create_channel
    step :update_memberships
    step :publish_channel

    # @!visibility private
    class Contract
      attribute :target_usernames

      before_validation do
        self.target_usernames =
          (
            if target_usernames.is_a?(String)
              target_usernames.split(",")
            else
              target_usernames
            end
          )
      end

      validates :target_usernames, presence: true, length: { minimum: 1 }
    end

    private

    def can_create_direct_message(guardian:, **)
      guardian.can_create_direct_message?
    end

    def fetch_target_users(guardian:, contract:, **)
      users = [guardian.user]
      other_usernames = contract.target_usernames - [guardian.user.username]
      users.concat(User.where(username: other_usernames).to_a) if other_usernames.any?
      users.uniq
    end

    def fetch_user_comm_screener(target_users:, guardian:, **)
      UserCommScreener.new(acting_user: guardian.user, target_user_ids: target_users.map(&:id))
    end

    def acting_user_not_disallowing_all_messages(user_comm_screener:, **)
      !user_comm_screener.actor_disallowing_all_pms?
    end

    def fetch_or_create_direct_message(target_users:, **)
      direct_message = Chat::DirectMessage.for_user_ids(target_users.map(&:id))
      return direct_message if direct_message.present?
      Chat::DirectMessage.create(user_ids: target_users.map(&:id))
    end

    def fetch_or_create_channel(direct_message:, **)
      channel = Chat::Channel.find_by(chatable: direct_message)
      channel.present? ? channel : direct_message.create_chat_channel
    end

    def update_memberships(guardian:, channel:, target_users:, **)
      sql_params = {
        acting_user_id: guardian.user.id,
        user_ids: target_users.map(&:id),
        chat_channel_id: channel.id,
        always_notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
      }

      DB.exec(<<~SQL, sql_params)
        INSERT INTO user_chat_channel_memberships(
          user_id,
          chat_channel_id,
          muted,
          following,
          desktop_notification_level,
          mobile_notification_level,
          created_at,
          updated_at
        )
        VALUES(
          unnest(array[:user_ids]),
          :chat_channel_id,
          false,
          false,
          :always_notification_level,
          :always_notification_level,
          NOW(),
          NOW()
        )
        ON CONFLICT (user_id, chat_channel_id) DO NOTHING;

        UPDATE user_chat_channel_memberships
        SET following = true
        WHERE user_id = :acting_user_id AND chat_channel_id = :chat_channel_id;
      SQL
    end

    def publish_channel(channel:, target_users:, **)
      Chat::Publisher.publish_new_channel(channel, target_users)
    end
  end
end
