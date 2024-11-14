# frozen_string_literal: true

require "faker"

module ChatSystemHelpers
  def chat_system_bootstrap(user = Fabricate(:admin), channels_for_membership = [])
    # ensures we have one valid registered admin/user
    user.activate

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]

    channels_for_membership.each do |channel|
      membership = channel.add(user)
      if channel.chat_messages.any?
        membership.update!(last_read_message_id: channel.chat_messages.last.id)
      end
    end

    Group.refresh_automatic_groups!
  end

  def chat_system_user_bootstrap(user:, channel:)
    user.activate
    user.user_option.update!(chat_enabled: true)
    Group.refresh_automatic_group!("trust_level_#{user.trust_level}".to_sym)
    channel.add(user)
  end

  def chat_thread_chain_bootstrap(channel:, users:, messages_count: 4, thread_attrs: {})
    last_user = nil
    last_message = nil

    users.each { |user| chat_system_user_bootstrap(user: user, channel: channel) }
    messages_count.times do |i|
      in_reply_to = i.zero? ? nil : last_message.id
      thread_id = i.zero? ? nil : last_message.thread_id
      last_user = ((users - [last_user]).presence || users).sample
      creator =
        Chat::CreateMessage.call(
          guardian: last_user.guardian,
          params: {
            chat_channel_id: channel.id,
            in_reply_to_id: in_reply_to,
            thread_id: thread_id,
            message: Faker::Alphanumeric.alpha(number: SiteSetting.chat_minimum_message_length),
          },
        )

      raise "#{creator.inspect_steps.inspect}\n\n#{creator.inspect_steps.error}" if creator.failure?
      last_message = creator.message_instance
    end

    last_message.thread.set_replies_count_cache(messages_count - 1, update_db: true)
    last_message.thread.update!(thread_attrs) if thread_attrs.any?
    last_message.thread
  end

  def thread_excerpt(message)
    message.excerpt
  end
end

module ChatSpecHelpers
  def service_failed!(result)
    raise RSpec::Expectations::ExpectationNotMetError.new(
            "Service failed, see below for step details:\n\n" + result.inspect_steps.inspect,
          )
  end

  def update_message!(message, text: nil, user: Discourse.system_user, upload_ids: nil)
    Chat::UpdateMessage.call(
      guardian: user.guardian,
      params: {
        message_id: message.id,
        upload_ids: upload_ids,
        message: text,
      },
      options: {
        process_inline: true,
      },
    ) do |result|
      on_success { result.message_instance }
      on_failure { service_failed!(result) }
    end
  end

  def trash_message!(message, user: Discourse.system_user)
    Chat::TrashMessage.call(
      params: {
        message_id: message.id,
        channel_id: message.chat_channel_id,
      },
      guardian: user.guardian,
    ) do |result|
      on_success { result }
      on_failure { service_failed!(result) }
    end
  end

  def restore_message!(message, user: Discourse.system_user)
    Chat::RestoreMessage.call(
      params: {
        message_id: message.id,
        channel_id: message.chat_channel_id,
      },
      guardian: user.guardian,
    ) do |result|
      on_success { result }
      on_failure { service_failed!(result) }
    end
  end

  def add_users_to_channel(users, channel, user: Discourse.system_user)
    ::Chat::AddUsersToChannel.call(
      guardian: user.guardian,
      params: {
        channel_id: channel.id,
        usernames: Array(users).map(&:username),
      },
    ) do |result|
      on_success { result }
      on_failure { service_failed!(result) }
    end
  end

  def create_draft(channel, thread: nil, user: Discourse.system_user, data: { message: "draft" })
    if data[:uploads]
      data[:uploads] = data[:uploads].map do |upload|
        UploadSerializer.new(upload, root: false).as_json
      end
    end

    ::Chat::UpsertDraft.call(
      guardian: user.guardian,
      params: {
        channel_id: channel.id,
        thread_id: thread&.id,
        data: data.to_json,
      },
    ) do |result|
      on_success { result }
      on_failure { service_failed!(result) }
    end
  end
end

RSpec.configure do |config|
  config.include ChatSystemHelpers, type: :system
  config.include ChatSpecHelpers

  config.expect_with :rspec do |c|
    # Or a very large value, if you do want to truncate at some point
    c.max_formatted_output_length = nil
  end
end
