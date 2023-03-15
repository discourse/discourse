# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class Message < Record
    def initialize
      super(Chat::Message, 200)
    end

    def data
      if Faker::Boolean.boolean(true_ratio: 0.5)
        channel =
          ::Chat::Channel.where(chatable_type: "Chat::DirectMessage").order("RANDOM()").first
        channel.user_chat_channel_memberships.update_all(following: true)
        user = channel.chatable.users.order("RANDOM()").first
      else
        membership = Chat::UserChatChannelMembership.order("RANDOM()").first
        channel = membership.chat_channel
        user = membership.user
      end

      { user: user, content: Faker::Lorem.paragraph, chat_channel: channel }
    end

    def create!
      Chat::MessageCreator.create(data)
    end
  end
end
