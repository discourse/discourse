# frozen_string_literal: true

module ChatHelper
  def self.make_messages!(chatable, users, count)
    users = [users] unless Array === users
    raise ArgumentError if users.length <= 0

    chatable = Fabricate(:category) unless chatable
    chat_channel = Fabricate(:chat_channel, chatable: chatable)

    count.times do |n|
      Chat::Message.new(
        chat_channel: chat_channel,
        user: users[n % users.length],
        message: "Chat message for test #{n}",
      ).save!
    end
  end
end
