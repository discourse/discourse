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

        thread = Chat::Thread.find_by(id: message.thread_id) if message.thread_id
      else
        chat_channel = Chat::Channel.find_by(id: route[:channel_id])
        return if !chat_channel

        thread = Chat::Thread.find_by(id: route[:thread_id]) if route[:thread_id]
      end

      return if !Guardian.new.can_preview_chat_channel?(chat_channel)

      args = build_args(url, chat_channel)

      if message.present?
        render_message_onebox(args, message, thread)
      else
        if thread.present?
          render_thread_onebox(args, thread)
        else
          render_channel_onebox(args, chat_channel)
        end
      end
    end

    private

    def self.build_args(url, chat_channel)
      args = {
        channel_id: chat_channel.id,
        channel_name: chat_channel.name,
        is_category: chat_channel.category_channel?,
        color: chat_channel.category_channel? ? chat_channel.chatable.color : nil,
      }
    end

    def self.render_thread_onebox(args, thread)
      args.merge!(
        cooked: build_thread_snippet(thread),
        thread_id: thread.id,
        thread_title: thread.title,
        thread_title_connector: I18n.t("chat.onebox.thread_title_connector"),
        images: get_image_uploads(thread),
      )

      Mustache.render(Chat.thread_onebox_template, args)
    end

    def self.render_message_onebox(args, message, thread)
      args.merge!(
        message_id: message.id,
        username: message.user.username,
        avatar_url: message.user.avatar_template_url.gsub("{size}", "20"),
        cooked: message.cooked,
        created_at: message.created_at,
        created_at_str: message.created_at.iso8601,
        thread_id: message.thread_id,
        thread_title: thread&.title,
        images: get_image_uploads(message),
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

    def self.get_image_uploads(target)
      if target.is_a?(Message)
        message = target
      elsif target.is_a?(Thread)
        message = Chat::Message.includes(:uploads).find_by(id: target.original_message_id)
      end

      return if !message
      message.uploads.select { |u| u.height.present? || u.width.present? }
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

    def self.build_thread_snippet(thread)
      message = Chat::Message.find_by(id: thread.original_message_id)
      return nil if !message
      message.cooked
    end
  end
end
