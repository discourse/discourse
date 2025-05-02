# frozen_string_literal: true

module Chat
  # Service responsible for joining the reply presence channel of a chat channel.
  # The client_id set in the context should be stored to be able to call Chat::StopReply later.
  #
  # @example
  #  Chat::StartReply.call(params: { channel_id: 3 }, guardian: guardian)
  #
  class StartReply
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id
    #   @option params [Integer] :thread_id
    #   @return [Service::Base::Context]
    params do
      attribute :channel_id, :integer
      attribute :thread_id, :integer

      validates :channel_id, presence: true

      def channel_name
        return "/chat-reply/#{channel_id}/thread/#{thread_id}" if thread_id
        "/chat-reply/#{channel_id}"
      end
    end

    model :presence_channel
    step :generate_client_id
    try(PresenceChannel::InvalidAccess) { step :join_chat_reply_presence_channel }

    private

    def fetch_presence_channel(params:)
      PresenceChannel.new(params.channel_name)
    end

    def generate_client_id
      context[:client_id] = SecureRandom.hex
    end

    def join_chat_reply_presence_channel(presence_channel:, guardian:, client_id:)
      presence_channel.present(user_id: guardian.user.id, client_id:)
    end
  end
end
