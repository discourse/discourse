# frozen_string_literal: true

Fabricator(:chat_channel) do
  name do
    sequence(:name) do |n|
      random_name = [
        "Gaming Lounge",
        "Music Lodge",
        "Random",
        "Politics",
        "Sports Center",
        "Kino Buffs",
      ].sample
      "#{random_name} #{n}"
    end
  end
  chatable { Fabricate(:category) }
  type do |attrs|
    if attrs[:chatable_type] == "Category" || attrs[:chatable]&.is_a?(Category)
      "CategoryChannel"
    else
      "DirectMessageChannel"
    end
  end
  status { :open }
end

Fabricator(:category_channel, from: :chat_channel, class_name: :category_channel) {}

Fabricator(:private_category_channel, from: :category_channel, class_name: :category_channel) do
  transient :group
  chatable { |attrs| Fabricate(:private_category, group: attrs[:group] || Group[:staff]) }
end

Fabricator(:direct_message_channel, from: :chat_channel, class_name: :direct_message_channel) do
  transient :users, following: true, with_membership: true
  chatable do |attrs|
    Fabricate(:direct_message, users: attrs[:users] || [Fabricate(:user), Fabricate(:user)])
  end
  status { :open }
  name nil
  after_create do |channel, attrs|
    if attrs[:with_membership]
      channel.chatable.users.each do |user|
        membership = channel.add(user)
        membership.update!(following: false) if attrs[:following] == false
      end
    end
  end
end

Fabricator(:chat_message) do
  chat_channel
  user
  message "Beep boop"
  cooked { |attrs| ChatMessage.cook(attrs[:message]) }
  cooked_version ChatMessage::BAKED_VERSION
  in_reply_to nil
end

Fabricator(:chat_mention) do
  transient read: false
  transient high_priority: true
  transient identifier: :direct_mentions

  user { Fabricate(:user) }
  chat_message { Fabricate(:chat_message) }
  notification do |attrs|
    # All this setup should be in a service we could just call here
    # At the moment the logic is all split in a job
    channel = attrs[:chat_message].chat_channel

    payload = {
      is_direct_message_channel: channel.direct_message_channel?,
      mentioned_by_username: attrs[:chat_message].user.username,
      chat_channel_id: channel.id,
      chat_message_id: attrs[:chat_message].id,
    }

    if channel.direct_message_channel?
      payload[:chat_channel_title] = channel.title(membership.user)
      payload[:chat_channel_slug] = channel.slug
    end

    unless attrs[:identifier] == :direct_mentions
      case attrs[:identifier]
      when :here_mentions
        payload[:identifier] = "here"
      when :global_mentions
        payload[:identifier] = "all"
      else
        payload[:identifier] = attrs[:identifier] if attrs[:identifier]
        payload[:is_group_mention] = true
      end
    end

    Fabricate(
      :notification,
      notification_type: Notification.types[:chat_mention],
      user: attrs[:user],
      data: payload.to_json,
      read: attrs[:read],
      high_priority: attrs[:high_priority],
    )
  end
end

Fabricator(:chat_message_reaction) do
  chat_message { Fabricate(:chat_message) }
  user { Fabricate(:user) }
  emoji { %w[+1 tada heart joffrey_facepalm].sample }
  after_build do |chat_message_reaction|
    chat_message_reaction.chat_message.chat_channel.add(chat_message_reaction.user)
  end
end

Fabricator(:chat_upload) do
  transient :user

  user { Fabricate(:user) }

  chat_message { |attrs| Fabricate(:chat_message, user: attrs[:user]) }
  upload { |attrs| Fabricate(:upload, user: attrs[:user]) }
end

Fabricator(:chat_message_revision) do
  chat_message { Fabricate(:chat_message) }
  old_message { "something old" }
  new_message { "something new" }
  user { |attrs| attrs[:chat_message].user }
end

Fabricator(:reviewable_chat_message) do
  reviewable_by_moderator true
  type "ReviewableChatMessage"
  created_by { Fabricate(:user) }
  target_type "ChatMessage"
  target { Fabricate(:chat_message) }
  reviewable_scores { |p| [Fabricate.build(:reviewable_score, reviewable_id: p[:id])] }
end

Fabricator(:direct_message) { users { [Fabricate(:user), Fabricate(:user)] } }

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

Fabricator(:chat_draft) do
  user
  chat_channel

  transient :value, "chat draft message"
  transient :uploads, []
  transient :reply_to_msg

  data do |attrs|
    { value: attrs[:value], replyToMsg: attrs[:reply_to_msg], uploads: attrs[:uploads] }.to_json
  end
end

Fabricator(:chat_thread) do
  before_create do |thread, transients|
    thread.original_message_user = original_message.user
    thread.channel = original_message.chat_channel
  end

  transient :channel

  original_message do |attrs|
    Fabricate(:chat_message, chat_channel: attrs[:channel] || Fabricate(:chat_channel))
  end
end
