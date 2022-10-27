# frozen_string_literal: true

Fabricator(:chat_channel) do
  name do
    ["Gaming Lounge", "Music Lodge", "Random", "Politics", "Sports Center", "Kino Buffs"].sample
  end
  chatable { Fabricate(:category) }
  status { :open }
end

Fabricator(:category_channel, from: :chat_channel, class_name: :category_channel) {}

Fabricator(:dm_channel, from: :chat_channel, class_name: :d_m_channel) do
  chatable { Fabricate(:direct_message_channel) }
end

Fabricator(:direct_message_chat_channel, from: :chat_channel, class_name: :d_m_channel) do
  transient :users
  chatable do |attrs|
    Fabricate(:direct_message_channel, users: attrs[:users] || [Fabricate(:user), Fabricate(:user)])
  end
  status { :open }
end

Fabricator(:chat_message) do
  chat_channel
  user
  message "Beep boop"
  cooked { |attrs| ChatMessage.cook(attrs[:message]) }
  cooked_version ChatMessage::BAKED_VERSION
end

Fabricator(:chat_mention) do
  chat_message { Fabricate(:chat_message) }
  user { Fabricate(:user) }
  notification { Fabricate(:notification) }
end

Fabricator(:chat_message_reaction) do
  chat_message { Fabricate(:chat_message) }
  user { Fabricate(:user) }
  emoji { %w[+1 tada heart joffrey_facepalm].sample }
end

Fabricator(:chat_upload) do
  chat_message { Fabricate(:chat_message) }
  upload { Fabricate(:upload) }
end

Fabricator(:chat_message_revision) do
  chat_message { Fabricate(:chat_message) }
  old_message { "something old" }
  new_message { "something new" }
end

Fabricator(:reviewable_chat_message) do
  reviewable_by_moderator true
  type "ReviewableChatMessage"
  created_by { Fabricate(:user) }
  target_type "ChatMessage"
  target { Fabricate(:chat_message) }
  reviewable_scores { |p| [Fabricate.build(:reviewable_score, reviewable_id: p[:id])] }
end

Fabricator(:direct_message_channel) { users { [Fabricate(:user), Fabricate(:user)] } }

Fabricator(:chat_webhook_event) do
  chat_message { Fabricate(:chat_message) }
  incoming_chat_webhook do |attrs|
    Fabricate(:incoming_chat_webhook, chat_channel: attrs[:chat_message].chat_channel)
  end
end

Fabricator(:incoming_chat_webhook) do
  name { sequence(:name) { |i| "#{i + 1}" } }
  key { sequence(:key) { |i| "#{i + 1}" } }
  chat_channel { Fabricate(:chat_channel, chatable: Fabricate(:category)) }
end

Fabricator(:user_chat_channel_membership) do
  user
  chat_channel
  following true
end

Fabricator(:user_chat_channel_membership_for_dm, from: :user_chat_channel_membership) do
  user
  chat_channel
  following true
  desktop_notification_level 2
  mobile_notification_level 2
end
