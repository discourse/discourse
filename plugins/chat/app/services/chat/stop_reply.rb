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
      attribute :client_id, :string
      attribute :thread_id, :integer

      validates :channel_id, presence: true
      validates :client_id, presence: true

      def channel_name
        return "/chat-reply/#{channel_id}/thread/#{thread_id}" if thread_id
        "/chat-reply/#{channel_id}"
      end
    end

    model :presence_channel
    step :leave_chat_reply_presence_channel

    private

    def fetch_presence_channel(params:)
      PresenceChannel.new(params.channel_name)
    end

    def leave_chat_reply_presence_channel(presence_channel:, params:, guardian:)
      presence_channel.leave(user_id: guardian.user.id, client_id: params.client_id)
    end
  end
end
