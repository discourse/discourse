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
      validates :channel_id, presence: true

      attribute :thread_id, :integer
    end

    model :presence_channel
    step :generate_client_id
    step :join_chat_reply_presence_channel

    private

    def fetch_presence_channel(params:)
      name = "/chat-reply/#{params.channel_id}"
      name += "/thread/#{params.thread_id}" if params.thread_id
      PresenceChannel.new(name)
    rescue PresenceChannel::NotFound
      nil
    end

    def generate_client_id
      context[:client_id] = SecureRandom.hex
    end

    def join_chat_reply_presence_channel(presence_channel:, guardian:)
      presence_channel.present(user_id: guardian.user.id, client_id: context.client_id)
    rescue PresenceChannel::InvalidAccess
      fail!("Presence channel not accessible by the user: #{guardian.user.id}")
    end
  end
end
