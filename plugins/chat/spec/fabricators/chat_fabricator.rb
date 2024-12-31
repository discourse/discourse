# frozen_string_literal: true

Fabricator(:chat_channel, class_name: "Chat::Channel") do
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
    if attrs[:chatable_type] == "Category" || attrs[:chatable].is_a?(Category)
      "CategoryChannel"
    else
      "DirectMessageChannel"
    end
  end
  status { :open }
end

Fabricator(:category_channel, from: :chat_channel) {}

Fabricator(:private_category_channel, from: :category_channel) do
  transient :group
  chatable { |attrs| Fabricate(:private_category, group: attrs[:group] || Group[:staff]) }
end

Fabricator(:direct_message_channel, from: :chat_channel) do
  transient :users, :group, following: true, with_membership: true
  chatable do |attrs|
    Fabricate(
      :direct_message,
      users: attrs[:users] || [Fabricate(:user), Fabricate(:user)],
      group: attrs[:group] || false,
    )
  end
  status { :open }
  name nil
  threading_enabled true
  after_create do |channel, attrs|
    if attrs[:with_membership]
      channel.chatable.users.each do |user|
        membership = channel.add(user)
        membership.update!(following: false) if attrs[:following] == false
      end
    end
  end
end

Fabricator(:chat_message, class_name: "Chat::Message") do
  transient use_service: false

  initialize_with do |transients|
    Fabricate(
      transients[:use_service] ? :chat_message_with_service : :chat_message_without_service,
      **to_params,
    )
  end
end

Fabricator(:chat_message_without_service, class_name: "Chat::Message") do
  user
  chat_channel
  message { Faker::Alphanumeric.alpha(number: [10, SiteSetting.chat_minimum_message_length].max) }

  after_build { |message, attrs| message.cook }
  after_create { |message, attrs| message.upsert_mentions }
end

Fabricator(:chat_message_with_service, class_name: "Chat::CreateMessage") do
  transient :chat_channel,
            :user,
            :message,
            :in_reply_to,
            :thread,
            :upload_ids,
            :incoming_chat_webhook,
            :blocks

  initialize_with do |transients|
    channel =
      transients[:chat_channel] || transients[:thread]&.channel ||
        transients[:in_reply_to]&.chat_channel || Fabricate(:chat_channel)
    user = transients[:user] || Fabricate(:user)
    Group.refresh_automatic_groups!
    channel.add(user)

    result =
      resolved_class.call(
        params: {
          chat_channel_id: channel.id,
          message:
            transients[:message] ||
              Faker::Alphanumeric.alpha(number: SiteSetting.chat_minimum_message_length),
          thread_id: transients[:thread]&.id,
          in_reply_to_id: transients[:in_reply_to]&.id,
          upload_ids: transients[:upload_ids],
          blocks: transients[:blocks],
        },
        options: {
          process_inline: true,
        },
        guardian: user.guardian,
        incoming_chat_webhook: transients[:incoming_chat_webhook],
      )

    if result.failure?
      raise RSpec::Expectations::ExpectationNotMetError.new(
              "Service `#{resolved_class}` failed, see below for step details:\n\n" +
                result.inspect_steps,
            )
    end

    result.message_instance
  end
end

Fabricator(:chat_mention_notification, class_name: "Chat::MentionNotification") do
  chat_mention { Fabricate(:user_chat_mention) }
  notification { Fabricate(:notification) }
end

Fabricator(:user_chat_mention, class_name: "Chat::UserMention") do
  transient read: false
  transient high_priority: true
  transient identifier: :direct_mentions

  user { Fabricate(:user) }
  chat_message { Fabricate(:chat_message) }
end

Fabricator(:group_chat_mention, class_name: "Chat::GroupMention") do
  chat_message { Fabricate(:chat_message) }
  group { Fabricate(:group) }
end

Fabricator(:all_chat_mention, class_name: "Chat::AllMention") do
  chat_message { Fabricate(:chat_message) }
end

Fabricator(:here_chat_mention, class_name: "Chat::HereMention") do
  chat_message { Fabricate(:chat_message) }
end

Fabricator(:chat_message_reaction, class_name: "Chat::MessageReaction") do
  chat_message { Fabricate(:chat_message) }
  user { Fabricate(:user) }
  emoji { %w[+1 tada heart joffrey_facepalm].sample }
  after_build do |chat_message_reaction|
    chat_message_reaction.chat_message.chat_channel.add(chat_message_reaction.user)
  end
end

Fabricator(:chat_message_revision, class_name: "Chat::MessageRevision") do
  chat_message { Fabricate(:chat_message) }
  old_message { "something old" }
  new_message { "something new" }
  user { |attrs| attrs[:chat_message].user }
end

Fabricator(:chat_reviewable_message, class_name: "Chat::ReviewableMessage") do
  reviewable_by_moderator true
  type "ReviewableChatMessage"
  created_by { Fabricate(:user) }
  target { Fabricate(:chat_message) }
  reviewable_scores { |p| [Fabricate.build(:reviewable_score, reviewable_id: p[:id])] }
end

Fabricator(:chat_message_interaction, class_name: "Chat::MessageInteraction") do
  message { Fabricate(:chat_message) }
  user { Fabricate(:user) }
end

Fabricator(:direct_message, class_name: "Chat::DirectMessage") do
  users { [Fabricate(:user), Fabricate(:user)] }
end

Fabricator(:chat_webhook_event, class_name: "Chat::WebhookEvent") do
  chat_message { Fabricate(:chat_message) }
  incoming_chat_webhook do |attrs|
    Fabricate(:incoming_chat_webhook, chat_channel: attrs[:chat_message].chat_channel)
  end
end

Fabricator(:incoming_chat_webhook, class_name: "Chat::IncomingWebhook") do
  name { sequence(:name) { |i| "Test webhook #{i + 1}" } }
  emoji { %w[:joy: :rocket: :handshake:].sample }
  chat_channel { Fabricate(:chat_channel, chatable: Fabricate(:category)) }
end

Fabricator(:user_chat_channel_membership, class_name: "Chat::UserChatChannelMembership") do
  user
  chat_channel
  following true
end

Fabricator(:user_chat_channel_membership_for_dm, from: :user_chat_channel_membership) do
  user
  chat_channel
  following true
  notification_level 2
end

Fabricator(:chat_draft, class_name: "Chat::Draft") do
  user
  chat_channel

  transient :value, "chat draft message"
  transient :uploads, []
  transient :reply_to_msg

  data do |attrs|
    { value: attrs[:value], replyToMsg: attrs[:reply_to_msg], uploads: attrs[:uploads] }.to_json
  end
end

Fabricator(:chat_thread, class_name: "Chat::Thread") do
  before_create do |thread, transients|
    thread.original_message_user = original_message.user
    thread.channel = original_message.chat_channel
  end

  transient :with_replies,
            :channel,
            :original_message_user,
            :old_om,
            use_service: false,
            notification_level: :tracking

  original_message do |attrs|
    Fabricate(
      :chat_message,
      chat_channel: attrs[:channel] || Fabricate(:chat_channel, threading_enabled: true),
      user: attrs[:original_message_user] || Fabricate(:user),
      use_service: attrs[:use_service],
    )
  end

  after_create do |thread, transients|
    attrs = { thread_id: thread.id }

    # Sometimes we  make this older via created_at so any messages fabricated for this thread
    # afterwards are not created earlier in time than the OM.
    attrs[:created_at] = 1.week.ago if transients[:old_om]

    thread.original_message.update!(**attrs)
    thread.add(thread.original_message_user, notification_level: transients[:notification_level])

    if transients[:with_replies]
      Fabricate
        .times(
          transients[:with_replies],
          :chat_message,
          thread: thread,
          use_service: transients[:use_service],
        )
        .each { |message| thread.add(message.user) }

      thread.update!(replies_count: transients[:with_replies])
    end
  end
end

Fabricator(:user_chat_thread_membership, class_name: "Chat::UserChatThreadMembership") do
  user
  after_create do |membership|
    Chat::UserChatChannelMembership.find_or_create_by!(
      user: membership.user,
      chat_channel: membership.thread.channel,
    ).update!(following: true)
  end
end
