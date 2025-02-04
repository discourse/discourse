# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::UnfollowChannel.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #    }
  #  )
  #
  class UnfollowChannel
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id ID of the channel
    #   @return [Service::Base::Context]

    params do
      attribute :channel_id, :integer

      validates :channel_id, presence: true
    end

    model :channel
    step :unfollow

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params.channel_id)
    end

    def unfollow(channel:, guardian:)
      context[:membership] = channel.remove(guardian.user)
    end
  end
end
