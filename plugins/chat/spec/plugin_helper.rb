# frozen_string_literal: true

require "faker"

module ChatSystemHelpers
  def chat_system_bootstrap(user = Fabricate(:admin), channels_for_membership = [])
    # ensures we have one valid registered admin/user
    user.activate

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

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
    Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user)
  end

  def chat_thread_chain_bootstrap(channel:, users:, messages_count: 4, thread_attrs: {})
    last_user = nil
    last_message = nil

    messages_count.times do |i|
      in_reply_to = i.zero? ? nil : last_message.id
      thread_id = i.zero? ? nil : last_message.thread_id
      last_user = last_user.present? ? (users - [last_user]).sample : users.sample
      creator =
        Chat::MessageCreator.new(
          chat_channel: channel,
          in_reply_to_id: in_reply_to,
          thread_id: thread_id,
          user: last_user,
          content: Faker::Lorem.paragraph,
        )
      creator.create

      raise creator.error if creator.error
      last_message = creator.chat_message
    end

    last_message.thread.set_replies_count_cache(messages_count - 1, update_db: true)
    last_message.thread.update!(thread_attrs) if thread_attrs.any?
    last_message.thread
  end

  def thread_excerpt(message)
    CGI.escapeHTML(
      message.censored_excerpt(max_length: ::Chat::Thread::EXCERPT_LENGTH).gsub("&hellip;", "…"),
    )
  end
end

module ChatSpecHelpers
  def service_failed!(result)
    raise RSpec::Expectations::ExpectationNotMetError.new(
            "Service failed, see below for step details:\n\n" + result.inspect_steps.inspect,
          )
  end
end

RSpec.configure do |config|
  config.include ChatSystemHelpers, type: :system
  config.include ChatSpecHelpers
  config.include Chat::WithServiceHelper
  config.include Chat::ServiceMatchers

  config.expect_with :rspec do |c|
    # Or a very large value, if you do want to truncate at some point
    c.max_formatted_output_length = nil
  end
end
