# frozen_string_literal: true

module Chat
  # Service responsible for leaving the reply presence channel of a chat channel.
  #
  # @example
  #  Chat::StopReply.call(params: { client_id: "xxx", channel_id: 3 }, guardian: guardian)
  #
  class StopReply
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :client_id
    #   @option params [Integer] :channel_id
    #   @option params [Integer] :thread_id
    #   @return [Service::Base::Context]
    params do
      attribute :channel_id, :integer
      validates :channel_id, presence: true

      attribute :client_id, :string
      validates :client_id, presence: true

      attribute :thread_id, :integer
    end

    model :presence_channel
    step :leave_chat_reply_presence_channel

    private

    def fetch_presence_channel(params:)
      name = "/chat-reply/#{params.channel_id}"
      name += "/thread/#{params.thread_id}" if params.thread_id
      PresenceChannel.new(name)
    rescue PresenceChannel::NotFound
      nil
    end

    def leave_chat_reply_presence_channel(presence_channel:, params:, guardian:)
      presence_channel.leave(user_id: guardian.user.id, client_id: params.client_id)
    end
  end
end
