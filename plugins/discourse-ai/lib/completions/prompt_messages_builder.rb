# frozen_string_literal: true
#
module DiscourseAi
  module Completions
    class PromptMessagesBuilder
      MAX_CHAT_UPLOADS = 5
      MAX_TOPIC_UPLOADS = 5
      attr_reader :chat_context_posts
      attr_accessor :topic

      def self.messages_from_chat(
        message,
        channel:,
        context_post_ids:,
        max_messages:,
        include_uploads:,
        bot_user_ids:,
        instruction_message: nil
      )
        include_thread_titles = !channel.direct_message_channel? && !message.thread_id

        current_id = message.id
        messages = nil

        if !message.thread_id && channel.direct_message_channel?
          messages = [message]
        elsif !channel.direct_message_channel? && !message.thread_id
          messages =
            Chat::Message
              .joins("left join chat_threads on chat_threads.id = chat_messages.thread_id")
              .where(chat_channel_id: channel.id)
              .where(
                "chat_messages.thread_id IS NULL OR chat_threads.original_message_id = chat_messages.id",
              )
              .order(id: :desc)
              .limit(max_messages)
              .to_a
              .reverse
        end

        messages ||=
          ChatSDK::Thread.last_messages(
            thread_id: message.thread_id,
            guardian: Discourse.system_user.guardian,
            page_size: max_messages,
          )

        builder = new

        guardian = Guardian.new(message.user)
        if context_post_ids
          builder.set_chat_context_posts(
            context_post_ids,
            guardian,
            include_uploads: include_uploads,
          )
        end

        messages.each do |m|
          # restore stripped message
          m.message = instruction_message if m.id == current_id && instruction_message

          if bot_user_ids.include?(m.user_id)
            builder.push(type: :model, content: m.message)
          else
            upload_ids = nil
            upload_ids = m.uploads.map(&:id) if include_uploads && m.uploads.present?
            mapped_message = m.message

            thread_title = nil
            thread_title = m.thread&.title if include_thread_titles && m.thread_id
            mapped_message = "(#{thread_title})\n#{m.message}" if thread_title

            if m.uploads.present?
              mapped_message =
                "#{mapped_message} -- uploaded(#{m.uploads.map(&:short_url).join(", ")})"
            end

            builder.push(
              type: :user,
              content: mapped_message,
              id: m.user.username,
              upload_ids: upload_ids,
            )
          end
        end

        builder.to_a(
          limit: max_messages,
          style: channel.direct_message_channel? ? :chat_with_context : :chat,
        )
      end

      def self.messages_from_post(post, style: nil, max_posts:, bot_usernames:, include_uploads:)
        # Pay attention to the `post_number <= ?` here.
        # We want to inject the last post as context because they are translated differently.

        post_types = [Post.types[:regular]]
        post_types << Post.types[:whisper] if post.post_type == Post.types[:whisper]

        context =
          post
            .topic
            .posts
            .joins(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .order("post_number desc")
            .where("post_type in (?)", post_types)
            .limit(max_posts)
            .pluck(
              "posts.raw",
              "users.username",
              "post_custom_prompts.custom_prompt",
              "(
                  SELECT array_agg(ref.upload_id)
                  FROM upload_references ref
                  WHERE ref.target_type = 'Post' AND ref.target_id = posts.id
               ) as upload_ids",
              "posts.created_at",
            )

        builder = new
        builder.topic = post.topic

        context.reverse_each do |raw, username, custom_prompt, upload_ids, created_at|
          custom_prompt_translation =
            Proc.new do |message|
              # We can't keep backwards-compatibility for stored functions.
              # Tool syntax requires a tool_call_id which we don't have.
              if message[2] != "function"
                custom_context = {
                  content: message[0],
                  type: message[2].present? ? message[2].to_sym : :model,
                }

                custom_context[:id] = message[1] if custom_context[:type] != :model
                custom_context[:name] = message[3] if message[3]

                thinking = message[4]
                custom_context[:thinking] = thinking if thinking
                custom_context[:created_at] = created_at

                builder.push(**custom_context)
              end
            end

          if custom_prompt.present?
            custom_prompt.each(&custom_prompt_translation)
          else
            context = { content: raw, type: (bot_usernames.include?(username) ? :model : :user) }

            context[:id] = username if context[:type] == :user

            if upload_ids.present? && context[:type] == :user && include_uploads
              context[:upload_ids] = upload_ids.compact
            end
            context[:created_at] = created_at

            builder.push(**context)
          end
        end

        builder.to_a(style: style || (post.topic.private_message? ? :bot : :topic))
      end

      def initialize
        @raw_messages = []
        @timestamps = {}
      end

      def set_chat_context_posts(post_ids, guardian, include_uploads:)
        posts = []
        Post
          .where(id: post_ids)
          .order("id asc")
          .each do |post|
            next if !guardian.can_see?(post)
            posts << post
          end
        if posts.present?
          posts_context = []
          posts_context << "\nThis chat is in the context of the Discourse topic '#{posts[0].topic.title}':\n\n"
          posts_context << "{{{\n"
          posts.each do |post|
            posts_context << "url: #{post.url}\n"
            posts_context << "#{post.username}: #{post.raw}\n\n"
            if include_uploads
              post.uploads.each { |upload| posts_context << { upload_id: upload.id } }
            end
          end
          posts_context << "}}}"
          @chat_context_posts = posts_context
        end
      end

      def to_a(limit: nil, style: nil)
        # topic and chat array are special, they are single messages that contain all history
        return chat_array(limit: limit) if style == :chat
        return topic_array if style == :topic

        # the rest of the styles can include multiple messages
        result = valid_messages_array(@raw_messages)
        prepend_chat_post_context(result) if style == :chat_with_context

        if limit
          result[0..limit]
        else
          result
        end
      end

      def push(type:, content:, name: nil, upload_ids: nil, id: nil, thinking: nil, created_at: nil)
        if !%i[user model tool tool_call system].include?(type)
          raise ArgumentError, "type must be either :user, :model, :tool, :tool_call or :system"
        end
        raise ArgumentError, "upload_ids must be an array" if upload_ids && !upload_ids.is_a?(Array)

        content = [content, *upload_ids.map { |upload_id| { upload_id: upload_id } }] if upload_ids
        message = { type: type, content: content }
        message[:name] = name.to_s if name
        message[:id] = id.to_s if id
        if thinking
          message[:thinking] = thinking["thinking"] if thinking["thinking"]
          message[:thinking_signature] = thinking["thinking_signature"] if thinking[
            "thinking_signature"
          ]
          message[:redacted_thinking_signature] = thinking[
            "redacted_thinking_signature"
          ] if thinking["redacted_thinking_signature"]
        end

        @raw_messages << message
        @timestamps[message] = created_at if created_at

        message
      end

      private

      def valid_messages_array(messages)
        result = []

        # this will create a "valid" messages array
        # 1. ensures we always start with a user message
        # 2. ensures we always end with a user message
        # 3. ensures we always interleave user and model messages
        last_type = nil
        messages.each do |message|
          if message[:type] == :model && !message[:content]
            message[:content] = "Reply cancelled by user."
          end

          next if !last_type && message[:type] != :user

          if last_type == :tool_call && message[:type] != :tool
            result.pop
            last_type = result.length > 0 ? result[-1][:type] : nil
          end

          next if message[:type] == :tool && last_type != :tool_call

          if message[:type] == last_type
            # merge the message for :user message
            # replace the message for other messages
            last_message = result[-1]

            if message[:type] == :user
              old_name = last_message.delete(:id)
              last_message[:content] = ["#{old_name}: ", last_message[:content]].flatten if old_name

              new_content = message[:content]
              new_content = ["#{message[:id]}: ", new_content].flatten if message[:id]

              if !last_message[:content].is_a?(Array)
                last_message[:content] = [last_message[:content]]
              end
              last_message[:content].concat(["\n", new_content].flatten)

              compressed =
                compress_messages_buffer(last_message[:content], max_uploads: MAX_TOPIC_UPLOADS)
              last_message[:content] = compressed
            else
              last_message[:content] = message[:content]
            end
          else
            result << message
          end

          last_type = message[:type]
        end

        result
      end

      def prepend_chat_post_context(messages)
        return if @chat_context_posts.blank?

        old_content = messages[0][:content]
        old_content = [old_content] if !old_content.is_a?(Array)

        new_content = []
        new_content << "You are replying inside a Discourse chat.\n"
        new_content.concat(@chat_context_posts)
        new_content << "\n"
        new_content << "Your instructions are:\n"
        new_content.concat(old_content)

        compressed = compress_messages_buffer(new_content.flatten, max_uploads: MAX_CHAT_UPLOADS)

        messages[0][:content] = compressed
      end

      def format_user_info(user)
        info = []
        info << user_role(user)
        info << "Trust level #{user.trust_level}" if user.trust_level > 0
        info << "#{account_age(user)}"
        info << "#{user.user_stat.post_count} posts" if user.user_stat.post_count.to_i > 0
        "#{user.username} (#{user.name}): #{info.compact.join(", ")}"
      end

      def format_timestamp(timestamp)
        return nil unless timestamp

        time_diff = Time.now - timestamp

        if time_diff < 1.minute
          "just now"
        elsif time_diff < 1.hour
          mins = (time_diff / 1.minute).round
          "#{mins} #{mins == 1 ? "minute" : "minutes"} ago"
        elsif time_diff < 1.day
          hours = (time_diff / 1.hour).round
          "#{hours} #{hours == 1 ? "hour" : "hours"} ago"
        elsif time_diff < 7.days
          days = (time_diff / 1.day).round
          "#{days} #{days == 1 ? "day" : "days"} ago"
        elsif time_diff < 30.days
          weeks = (time_diff / 7.days).round
          "#{weeks} #{weeks == 1 ? "week" : "weeks"} ago"
        elsif time_diff < 365.days
          months = (time_diff / 30.days).round
          "#{months} #{months == 1 ? "month" : "months"} ago"
        else
          years = (time_diff / 365.days).round
          "#{years} #{years == 1 ? "year" : "years"} ago"
        end
      end

      def user_role(user)
        return "moderator" if user.moderator?
        return "admin" if user.admin?
        nil
      end

      def account_age(user)
        years = ((Time.now - user.created_at) / 1.year).round
        months = ((Time.now - user.created_at) / 1.month).round % 12

        output = []
        if years > 0
          output << years.to_s
          output << "year" if years == 1
          output << "years" if years > 1
        end
        if months > 0
          output << months.to_s
          output << "month" if months == 1
          output << "months" if months > 1
        end

        if output.empty?
          "new account"
        else
          "account age: " + output.join(" ")
        end
      end

      def format_topic_info(topic)
        content_array = []

        if topic.private_message?
          content_array << "Private message info.\n"
        else
          content_array << "Topic information:\n"
        end

        content_array << "- URL: #{topic.url}\n"
        content_array << "- Title: #{topic.title}\n"
        if SiteSetting.tagging_enabled
          tags = topic.tags.pluck(:name)
          tags -= DiscourseTagging.hidden_tag_names if tags.present?
          content_array << "- Tags: #{tags.join(", ")}\n" if tags.present?
        end
        if !topic.private_message?
          content_array << "- Category: #{topic.category.name}\n" if topic.category
        end
        content_array << "- Number of replies: #{topic.posts_count - 1}\n\n"

        content_array.join
      end

      def format_user_infos(usernames)
        content_array = []

        if usernames.present?
          users_details =
            User
              .where(username: usernames)
              .includes(:user_stat)
              .map { |user| format_user_info(user) }
              .compact
          content_array << "User information:\n"
          content_array << "- #{users_details.join("\n- ")}\n\n" if users_details.present?
        end
        content_array.join
      end

      def topic_array
        raw_messages = @raw_messages.dup
        content_array = []
        content_array << "You are operating in a Discourse forum.\n\n"
        content_array << format_topic_info(@topic) if @topic

        if raw_messages.present?
          usernames =
            raw_messages.filter { |message| message[:type] == :user }.map { |message| message[:id] }

          content_array << format_user_infos(usernames) if usernames.present?
        end

        last_user_message = raw_messages.pop

        if raw_messages.present?
          content_array << "Here is the conversation so far:\n"
          raw_messages.each do |message|
            content_array << "#{message[:id] || "User"}: "
            timestamp = @timestamps[message]
            content_array << "(#{format_timestamp(timestamp)}) " if timestamp
            content_array << message[:content]
            content_array << "\n\n"
          end
        end

        if last_user_message
          content_array << "Latest post is by #{last_user_message[:id] || "User"} who just posted:\n"
          content_array << last_user_message[:content]
        end

        content_array =
          compress_messages_buffer(content_array.flatten, max_uploads: MAX_TOPIC_UPLOADS)

        user_message = { type: :user, content: content_array }

        [user_message]
      end

      def chat_array(limit:)
        if @raw_messages.length > 1
          buffer = [
            +"You are replying inside a Discourse chat channel. Here is a summary of the conversation so far:\n{{{",
          ]

          @raw_messages[0..-2].each do |message|
            buffer << "\n"

            if message[:type] == :user
              buffer << "#{message[:id] || "User"}: "
            else
              buffer << "Bot: "
            end

            buffer << message[:content]
          end

          buffer << "\n}}}"
          buffer << "\n\n"
          buffer << "Your instructions:"
          buffer << "\n"
        end

        last_message = @raw_messages[-1]
        buffer << "#{last_message[:id] || "User"}: "
        buffer << last_message[:content]

        buffer = compress_messages_buffer(buffer.flatten, max_uploads: MAX_CHAT_UPLOADS)

        message = { type: :user, content: buffer }
        [message]
      end

      # caps uploads to maximum uploads allowed in message stream
      # and concats string elements
      def compress_messages_buffer(buffer, max_uploads:)
        compressed = []
        current_text = +""
        upload_count = 0

        buffer.each do |item|
          if item.is_a?(String)
            current_text << item
          elsif item.is_a?(Hash)
            compressed << current_text if current_text.present?
            compressed << item
            current_text = +""
            upload_count += 1
          end
        end

        compressed << current_text if current_text.present?

        if upload_count > max_uploads
          to_remove = upload_count - max_uploads
          removed = 0
          compressed.delete_if { |item| item.is_a?(Hash) && (removed += 1) <= to_remove }
        end

        compressed = compressed[0] if compressed.length == 1 && compressed[0].is_a?(String)

        compressed
      end
    end
  end
end
