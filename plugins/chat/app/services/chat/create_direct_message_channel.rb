# frozen_string_literal: true

module Chat
  # Service responsible for creating a new direct message chat channel.
  # The guardian passed in is the "acting user" when creating the channel
  # and deciding whether the actor can communicate with the users that
  # are passed in.
  #
  # @example
  #  ::Chat::CreateDirectMessageChannel.call(
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
    policy :satisfies_dms_max_users_limit,
           class_name: Chat::DirectMessageChannel::MaxUsersExcessPolicy
    model :user_comm_screener
    policy :actor_allows_dms
    policy :targets_allow_dms_from_user,
           class_name: Chat::DirectMessageChannel::CanCommunicateAllPartiesPolicy
    model :direct_message, :fetch_or_create_direct_message
    model :channel, :fetch_or_create_channel
    step :set_optional_name
    step :update_memberships
    step :recompute_users_count

    # @!visibility private
    class Contract
      attribute :name, :string
      attribute :target_usernames, :array
      validates :target_usernames, presence: true
    end

    private

    def can_create_direct_message(guardian:, **)
      guardian.can_create_direct_message?
    end

    def fetch_target_users(guardian:, contract:, **)
      User.where(username: [guardian.user.username, *contract.target_usernames]).to_a
    end

    def fetch_user_comm_screener(target_users:, guardian:, **)
      UserCommScreener.new(acting_user: guardian.user, target_user_ids: target_users.map(&:id))
    end

    def actor_allows_dms(user_comm_screener:, **)
      !user_comm_screener.actor_disallowing_all_pms?
    end

    def fetch_or_create_direct_message(target_users:, contract:, **)
      ids = target_users.map(&:id)

      if ids.size > 2 || contract.name.present?
        ::Chat::DirectMessage.create(user_ids: ids, group: true)
      else
        ::Chat::DirectMessage.for_user_ids(ids) || ::Chat::DirectMessage.create(user_ids: ids)
      end
    end

    def fetch_or_create_channel(direct_message:, **)
      ::Chat::DirectMessageChannel.find_or_create_by(chatable: direct_message)
    end

    def set_optional_name(channel:, contract:, **)
      channel.update!(name: contract.name) if contract.name&.length&.positive?
    end

    def update_memberships(channel:, target_users:, **)
      always_level = ::Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always]

      memberships =
        target_users.map do |user|
          {
            user_id: user.id,
            chat_channel_id: channel.id,
            muted: false,
            following: false,
            desktop_notification_level: always_level,
            mobile_notification_level: always_level,
            created_at: Time.zone.now,
            updated_at: Time.zone.now,
          }
        end

      ::Chat::UserChatChannelMembership.upsert_all(
        memberships,
        unique_by: %i[user_id chat_channel_id],
      )
    end

    def recompute_users_count(channel:, **)
      channel.update!(
        user_count: ::Chat::ChannelMembershipsQuery.count(channel),
        user_count_stale: false,
      )
    end
  end
end
