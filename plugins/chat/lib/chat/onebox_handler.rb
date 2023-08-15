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

      args = {
        url: url,
        channel_id: chat_channel.id,
        channel_name: chat_channel.name,
        is_category: chat_channel.category_channel?,
        color: chat_channel.category_channel? ? chat_channel.chatable.color : nil,
      }

      if message.present?
        render_message_onebox(args, message)
      else
        render_channel_onebox(args, chat_channel)
      end
    end

    private

    def self.render_message_onebox(args, message)
      args[:message_id] = message.id
      args[:username] = message.user.username
      args[:avatar_url] = message.user.avatar_template_url.gsub("{size}", "20")
      args[:cooked] = message.cooked
      args[:created_at] = message.created_at
      args[:created_at_str] = message.created_at.iso8601

      Mustache.render(Chat.message_onebox_template, args)
    end

    def self.render_channel_onebox(args, chat_channel)
      users =
        Chat::ChannelMembershipsQuery
          .call(channel: chat_channel, limit: 10)
          .map do |membership|
            {
              username: membership.user.username,
              avatar_url: membership.user.avatar_template_url.gsub("{size}", "60"),
            }
          end

      remaining_user_count_str =
        if chat_channel.user_count > users.size
          I18n.t("chat.onebox.and_x_others", count: chat_channel.user_count - users.size)
        end

      args[:users] = users
      args[:user_count_str] = I18n.t("chat.onebox.x_members", count: chat_channel.user_count)
      args[:remaining_user_count_str] = remaining_user_count_str
      args[:description] = chat_channel.description

      Mustache.render(Chat.channel_onebox_template, args)
    end
  end
end
