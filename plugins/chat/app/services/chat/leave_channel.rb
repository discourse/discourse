# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::LeaveChannel.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #    }
  #  )
  #
  class LeaveChannel
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id ID of the channel
    #   @return [Service::Base::Context]

    contract do
      attribute :channel_id, :integer

      validates :channel_id, presence: true
    end
    model :channel
    step :leave
    step :recompute_users_count

    private

    def fetch_channel(contract:)
      Chat::Channel.find_by(id: contract.channel_id)
    end

    def leave(channel:, guardian:)
      channel.leave(guardian.user)
    end

    def recompute_users_count(channel:)
      channel.update!(
        user_count: ::Chat::ChannelMembershipsQuery.count(channel),
        user_count_stale: false,
      )
    end
  end
end
