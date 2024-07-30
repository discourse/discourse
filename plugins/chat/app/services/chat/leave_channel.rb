# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::LeaveChannel.call(
  #    guardian: guardian,
  #    channel_id: 1,
  #  )
  #
  class LeaveChannel
    include Service::Base

    # @!method call(guardian:, channel_id:,)
    #   @param [Guardian] guardian
    #   @param [Integer] channel_id of the channel

    #   @return [Service::Base::Context]
    contract
    model :channel
    step :leave
    step :recompute_users_count

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      validates :channel_id, presence: true
    end

    private

    def fetch_channel(contract:)
      Chat::Channel.find_by(id: contract.channel_id)
    end

    def leave(channel:, guardian:)
      ActiveRecord::Base.transaction do
        if channel.direct_message_channel? && channel.chatable&.group
          channel.membership_for(guardian.user)&.destroy!
          channel.chatable.direct_message_users.where(user_id: guardian.user.id).destroy_all
        else
          channel.remove(guardian.user)
        end
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
