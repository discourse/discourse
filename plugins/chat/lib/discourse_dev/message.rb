# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class Message < Record
    def initialize(channel_id: nil, count: nil, ignore_current_count: false)
      @channel_id = channel_id
      @ignore_current_count = ignore_current_count
      super(::Chat::Message, count&.to_i || 200)
    end

    def data
      if @channel_id
        channel = ::Chat::Channel.find(@channel_id)
      else
        channel = ::Chat::Channel.where(chatable_type: "Category").order("RANDOM()").first
      end

      return if !channel

      membership =
        ::Chat::UserChatChannelMembership.where(chat_channel: channel).order("RANDOM()").first
      user = membership.user

      {
        guardian: user.guardian,
        params: {
          message: Faker::Lorem.paragraph,
          chat_channel_id: channel.id,
        },
      }
    end

    def create!
      message = nil
      Chat::CreateMessage.call(data) do
        on_success { |message_instance:| message = message_instance }
      end
      message
    end
  end
end
