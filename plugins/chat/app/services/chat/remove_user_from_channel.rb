# frozen_string_literal: true

module Chat
  # Service responsible for removing users from a channel.
  # The guardian passed in is the "acting user" when removing users.
  # The service is essentially deleting memberships for the users.
  #
  # @example
  #  ::Chat::RemoveUserFromChannel.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #      user_id: 9,
  #    }
  #  )
  #
  class RemoveUserFromChannel
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id ID of the channel
    #   @option params [Integer] :user_id
    #   @return [Service::Base::Context]

    params do
      attribute :user_id, :integer
      attribute :channel_id, :integer

      validates :user_id, presence: true
      validates :channel_id, presence: true
    end

    model :channel
    model :target_user

    policy :can_remove_users_from_channel

    transaction do
      step :remove
      step :recompute_users_count
    end

    private

    def fetch_channel(params:)
      ::Chat::Channel.includes(:chatable).find_by(id: params.channel_id)
    end

    def fetch_target_user(params:)
      User.find_by(id: params.user_id)
    end

    def can_remove_users_from_channel(guardian:, channel:)
      guardian.can_remove_members?(channel)
    end

    def remove(channel:, target_user:)
      if channel.direct_message_channel?
        channel.leave(target_user)
      else
        channel.remove(target_user)
      end
    end

    def recompute_users_count(channel:)
      channel.update!(
        user_count: ::Chat::ChannelMembershipsQuery.count(channel),
        user_count_stale: false,
      )
    end
  end
end
