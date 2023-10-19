# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class Thread < Record
    def initialize(channel_id:, message_count: nil, ignore_current_count: false)
      @channel_id = channel_id
      @message_count = message_count&.to_i || 30
      @ignore_current_count = ignore_current_count
      super(::Chat::Thread, 1)
    end

    def data
      channel = ::Chat::Channel.find(@channel_id)
      return if !channel

      if !channel.threading_enabled
        puts "Enabling threads in channel #{channel.id}"
        channel.update!(threading_enabled: true)
      end

      membership =
        ::Chat::UserChatChannelMembership.where(chat_channel: channel).order("RANDOM()").first
      user = membership.user

      om =
        Chat::CreateMessage.call(
          guardian: user.guardian,
          message: Faker::Lorem.paragraph,
          chat_channel_id: channel.id,
        ).message

      { original_message_user: user, original_message: om, channel: channel }
    end

    def create!
      super do |thread|
        thread.original_message.update!(thread: thread)
        user =
          ::Chat::UserChatChannelMembership
            .where(chat_channel: thread.channel)
            .order("RANDOM()")
            .first
            .user
        @message_count.times do
          Chat::CreateMessage.call(
            {
              guardian: user.guardian,
              chat_channel_id: thread.channel_id,
              message: Faker::Lorem.paragraph,
              thread_id: thread.id,
            },
          )
        end
      end
    end
  end
end
