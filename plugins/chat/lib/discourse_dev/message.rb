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

      { user: user, content: Faker::Lorem.paragraph, chat_channel: channel }
    end

    def create!
      Chat::MessageCreator.create(data)
    end
  end
end
