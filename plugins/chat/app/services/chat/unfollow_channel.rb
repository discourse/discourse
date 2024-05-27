# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::UnfollowChannel.call(
  #    guardian: guardian,
  #    channel_id: 1,
  #  )
  #
  class UnfollowChannel
    include Service::Base

    # @!method call(guardian:, channel_id:,)
    #   @param [Guardian] guardian
    #   @param [Integer] channel_id of the channel

    #   @return [Service::Base::Context]
    contract
    model :channel
    step :unfollow

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      validates :channel_id, presence: true
    end

    private

    def fetch_channel(contract:)
      Chat::Channel.find_by(id: contract.channel_id)
    end

    def unfollow(channel:, guardian:)
      context.membership = channel.remove(guardian.user)
    end
  end
end
