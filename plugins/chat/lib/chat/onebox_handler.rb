# frozen_string_literal: true

module Chat
  class OneboxHandler
    def self.handle(url, route)
      if route[:message_id].present?
        message = Chat::Message.find_by(id: route[:message_id])
        return if !message

        chat_channel = message.chat_channel
        user = message.user
        return if !chat_channel || !user
      else
        chat_channel = Chat::Channel.find_by(id: route[:channel_id])
        return if !chat_channel
      end

      return if !Guardian.new.can_preview_chat_channel?(chat_channel)

      args = build_args(url, chat_channel)

      if message.present?
        render_message_onebox(args, message)
      else
        render_channel_onebox(args, chat_channel)
      end
    end

    private

    def self.build_args(url, chat_channel)
      args = {
        url: url,
        channel_id: chat_channel.id,
        channel_name: chat_channel.name,
        is_category: chat_channel.category_channel?,
        color: chat_channel.category_channel? ? chat_channel.chatable.color : nil,
      }
    end

    def self.render_message_onebox(args, message)
      args.merge!(
        message_id: message.id,
        username: message.user.username,
        avatar_url: message.user.avatar_template_url.gsub("{size}", "20"),
        cooked: message.cooked,
        created_at: message.created_at,
        created_at_str: message.created_at.iso8601,
      )

      Mustache.render(Chat.message_onebox_template, args)
    end

    def self.render_channel_onebox(args, chat_channel)
      users = build_users_list(chat_channel)

      remaining_user_count_str = build_remaining_user_count_str(chat_channel, users)

      args.merge!(
        users: users,
        user_count_str: I18n.t("chat.onebox.x_members", count: chat_channel.user_count),
        remaining_user_count_str: remaining_user_count_str,
        description: chat_channel.description,
      )

      Mustache.render(Chat.channel_onebox_template, args)
    end

    def self.build_users_list(chat_channel)
      Chat::ChannelMembershipsQuery
        .call(channel: chat_channel, limit: 10)
        .map do |membership|
          {
            username: membership.user.username,
            avatar_url: membership.user.avatar_template_url.gsub("{size}", "60"),
          }
        end
    end

    def self.build_remaining_user_count_str(chat_channel, users)
      if chat_channel.user_count > users.size
        I18n.t("chat.onebox.and_x_others", count: chat_channel.user_count - users.size)
      end
    end
  end
end
