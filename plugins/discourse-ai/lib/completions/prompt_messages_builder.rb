# frozen_string_literal: true
#
module DiscourseAi
  module Completions
    class PromptMessagesBuilder
      MAX_CHAT_UPLOADS = 5
      MAX_TOPIC_UPLOADS = 5
      MAX_CONTEXT_MESSAGES = 1000
      MAX_RECOVERY_BYTES = 32.megabytes
      PUBLIC_CONTEXT_MESSAGES = 40
      COMPRESSED_CONTEXT_PREFIX = "<compressed_context>"
      COMPRESSED_CONTEXT_SUFFIX = "</compressed_context>"
      COMPRESSED_CONTEXT_ACK = "Understood, I have the context."
      attr_reader :chat_context_posts
      attr_accessor :topic, :preserve_history

      def self.messages_from_chat(
        message,
        channel:,
        context_post_ids:,
        max_messages:,
        context_token_budget: nil,
        tokenizer: nil,
        include_uploads: nil,
        include_image_uploads: nil,
        include_document_uploads: nil,
        allowed_attachment_types: nil,
        bot_user_ids:,
        instruction_message: nil,
        history_snapshot: nil
      )
        include_image_uploads, include_document_uploads =
          normalize_upload_inclusion(
            include_uploads,
            include_image_uploads,
            include_document_uploads,
          )
        include_thread_titles = !channel.direct_message_channel? && !message.thread_id

        current_id = message.id
        public_context = !channel.direct_message_channel? && !message.thread_id
        load_limit = max_messages
        load_limit = [max_messages, PUBLIC_CONTEXT_MESSAGES].min if public_context &&
          history_snapshot
        messages = nil
        coverage_boundary = nil

        if !message.thread_id && channel.direct_message_channel?
          messages =
            if history_snapshot
              recovered, coverage_boundary =
                recover_chat_messages(
                  Chat::Message.where(chat_channel_id: channel.id).where("id <= ?", current_id),
                  history_snapshot,
                )
              recovered
            else
              [message]
            end
        elsif !channel.direct_message_channel? && !message.thread_id
          messages =
            Chat::Message
              .includes(:user, :uploads, :thread)
              .joins("left join chat_threads on chat_threads.id = chat_messages.thread_id")
              .where(chat_channel_id: channel.id)
              .where("chat_messages.id <= ?", current_id)
              .where(
                "chat_messages.thread_id IS NULL OR chat_threads.original_message_id = chat_messages.id",
              )
              .order(id: :desc)
              .limit(load_limit + (history_snapshot && !public_context ? 1 : 0))
              .to_a
              .reverse
        end

        if !messages && history_snapshot
          thread = message.thread
          message.user.guardian.ensure_can_preview_chat_channel!(channel)
          if !thread || thread.channel_id != channel.id ||
               !(channel.threading_enabled || thread.force) ||
               !message.user.guardian.can_join_chat_channel?(channel)
            raise ContextPreparation::Error.new("history_changed")
          end
          messages, coverage_boundary =
            recover_chat_messages(
              Chat::Message.where(chat_channel_id: channel.id, thread_id: thread.id).where(
                "id <= ?",
                current_id,
              ),
              history_snapshot,
            )
        end
        messages ||=
          ChatSDK::Thread.last_messages(
            thread_id: message.thread_id,
            guardian: message.user.guardian,
            page_size: load_limit,
          )

        builder = new
        builder.preserve_history = history_snapshot.present?

        guardian = Guardian.new(message.user)
        if context_post_ids
          builder.set_chat_context_posts(
            context_post_ids,
            guardian,
            include_image_uploads: include_image_uploads,
            include_document_uploads: include_document_uploads,
            allowed_attachment_types: allowed_attachment_types,
          )
        end

        custom_prompts =
          if history_snapshot
            ChatMessageCustomPrompt
              .where(message_id: messages.map(&:id))
              .pluck(:message_id, :custom_prompt)
              .to_h
          else
            {}
          end
        if history_snapshot
          requester_id = nil
          messages.each do |entry|
            if !bot_user_ids.include?(entry.user_id)
              requester_id = entry.user_id
            else
              custom_prompts[entry.id] = history_snapshot.filter_evidence(
                custom_prompts[entry.id],
                requester_id: requester_id,
              )
            end
          end
          carrier =
            !public_context &&
              messages.reverse.find do |entry|
                usable_checkpoint(
                  custom_prompts[entry.id],
                  history_snapshot,
                  entry.id,
                  minimum_coverage: coverage_boundary,
                )
              end
          raise ContextPreparation::Error.new("history_changed") if coverage_boundary && !carrier
          if carrier
            prefix, remainder, boundary =
              checkpoint_parts(custom_prompts[carrier.id], history_snapshot)
            messages = messages.select { |entry| entry.id > boundary }
            custom_prompts[carrier.id] = remainder
            push_checkpoint_prefix(
              builder,
              prefix,
              guardian: guardian,
              include_image_uploads: include_image_uploads,
              include_document_uploads: include_document_uploads,
              allowed_attachment_types: allowed_attachment_types,
            )
          end
          custom_prompts.transform_values! do |entries|
            entries = without_checkpoint(entries)
            public_context ? without_public_requests(entries) : entries
          end
        end

        messages.each do |m|
          # restore stripped message
          m.message = instruction_message if m.id == current_id && instruction_message

          if bot_user_ids.include?(m.user_id)
            if custom_prompts[m.id].present?
              custom_prompts[m.id].each do |entry|
                next if entry[2] == "function"
                builder.push(
                  type: entry[2].present? ? entry[2].to_sym : :model,
                  content:
                    filtered_custom_prompt_content(
                      entry[0],
                      include_image_uploads: include_image_uploads,
                      include_document_uploads: include_document_uploads,
                      allowed_attachment_types: allowed_attachment_types,
                      guardian: guardian,
                    ),
                  id: entry[1],
                  name: entry[3],
                  thinking: entry[4],
                  provider_data: entry[5],
                )
              end
            else
              builder.push(
                type: :model,
                content: DiscourseAi::AiBot::ChatToolApproval.transcript_text(m),
              )
            end
          else
            upload_ids =
              filtered_upload_ids_from_uploads(
                m.uploads,
                include_image_uploads: include_image_uploads,
                include_document_uploads: include_document_uploads,
                allowed_attachment_types: allowed_attachment_types,
                guardian: guardian,
              )
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

        builder.trim_to_token_budget!(context_token_budget, tokenizer:)
        builder.prepend_scope_notice!(load_limit) if public_context && history_snapshot

        builder.to_a(
          limit: history_snapshot ? nil : max_messages,
          style:
            (
              if channel.direct_message_channel? || (history_snapshot && message.thread_id)
                :chat_with_context
              else
                :chat
              end
            ),
        )
      end

      def self.messages_from_post(
        post,
        guardian: post.user.guardian,
        style: nil,
        max_posts:,
        context_token_budget: nil,
        tokenizer: nil,
        bot_usernames:,
        include_uploads: nil,
        include_image_uploads: nil,
        include_document_uploads: nil,
        allowed_attachment_types: nil,
        history_snapshot: nil
      )
        include_image_uploads, include_document_uploads =
          normalize_upload_inclusion(
            include_uploads,
            include_image_uploads,
            include_document_uploads,
          )

        # Pay attention to the `post_number <= ?` here.
        # We want to inject the last post as context because they are translated differently.

        post_types = [Post.types[:regular]]
        post_types << Post.types[:whisper] if post.post_type == Post.types[:whisper]

        context_query =
          post
            .topic
            .posts
            .joins(:topic)
            .joins(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .where("post_type in (?)", post_types)

        public_context = !post.topic.private_message?
        load_limit = max_posts
        load_limit = [max_posts, PUBLIC_CONTEXT_MESSAGES].min if public_context && history_snapshot
        columns = [
          "posts.raw",
          "users.username",
          "post_custom_prompts.custom_prompt",
          "(SELECT array_agg(ref.upload_id) FROM upload_references ref JOIN uploads u ON u.id = ref.upload_id WHERE ref.target_type = 'Post' AND ref.target_id = posts.id) as upload_ids",
          "posts.created_at",
          "posts.user_id",
          "posts.post_number",
        ]
        visible_query = guardian.filter_hidden_posts(context_query, category: post.topic.category)
        if history_snapshot && !public_context
          context = []
          bytes = 0
          coverage_boundary = nil
          loop do
            page =
              visible_query.order(post_number: :desc).limit(MAX_CONTEXT_MESSAGES).pluck(*columns)
            break if page.empty?
            if !coverage_boundary
              carrier =
                page.find do |row|
                  history_snapshot.authorized_evidence?(row[2]) &&
                    usable_checkpoint(row[2], history_snapshot, row[6])
                end
              coverage_boundary =
                history_snapshot.covered_position(checkpoint_entry(carrier[2])[6]) if carrier
            end
            page = page.select { |row| row[6] > coverage_boundary } if coverage_boundary
            bytes += page.to_json.bytesize
            if bytes > MAX_RECOVERY_BYTES
              raise ContextPreparation::Error.new("history_recovery_limit")
            end
            context.concat(page)
            break if coverage_boundary && (page.empty? || page.last[6] <= coverage_boundary + 1)
            break if page.length < MAX_CONTEXT_MESSAGES
            visible_query = visible_query.where("posts.post_number < ?", page.last[6])
          end
        else
          context = visible_query.order(post_number: :desc).limit(load_limit).pluck(*columns)
        end

        evidence_snapshot =
          history_snapshot ||
            HistorySnapshot.post(
              post,
              guardian: guardian,
              bot_usernames: bot_usernames,
              capture_metadata: false,
            )
        requester_id = nil
        context.reverse_each do |row|
          if !bot_usernames.include?(row[1])
            requester_id = row[5]
          else
            row[2] = evidence_snapshot.filter_evidence(row[2], requester_id: requester_id)
          end
        end
        builder = new
        builder.preserve_history = history_snapshot.present?
        builder.topic = post.topic
        if history_snapshot
          carrier =
            !public_context &&
              context.find do |row|
                usable_checkpoint(
                  row[2],
                  history_snapshot,
                  row[6],
                  minimum_coverage: coverage_boundary,
                )
              end
          raise ContextPreparation::Error.new("history_changed") if coverage_boundary && !carrier
          if carrier
            prefix, remainder, boundary = checkpoint_parts(carrier[2], history_snapshot)
            context = context.select { |row| row[6] > boundary }
            carrier[2] = remainder
            push_checkpoint_prefix(
              builder,
              prefix,
              guardian: guardian,
              include_image_uploads: include_image_uploads,
              include_document_uploads: include_document_uploads,
              allowed_attachment_types: allowed_attachment_types,
            )
          end
          context.each do |row|
            next if !row[2]
            row[2] = without_checkpoint(row[2])
            row[2] = without_public_requests(row[2]) if public_context
          end
        end

        context.reverse_each do |raw, username, custom_prompt, upload_ids, created_at|
          filtered_upload_ids =
            filtered_upload_ids_for_prompt(
              upload_ids,
              include_image_uploads: include_image_uploads,
              include_document_uploads: include_document_uploads,
              allowed_attachment_types: allowed_attachment_types,
              guardian: guardian,
            )
          remaining_upload_ids = Array(filtered_upload_ids).dup
          uploads_by_id = Upload.where(id: remaining_upload_ids).index_by(&:id)

          custom_prompt_translation =
            Proc.new do |message|
              # We can't keep backwards-compatibility for stored functions.
              # Tool syntax requires a tool_call_id which we don't have.
              if message[2] != "function"
                custom_context = {
                  content:
                    filtered_custom_prompt_content(
                      message[0],
                      include_image_uploads: include_image_uploads,
                      include_document_uploads: include_document_uploads,
                      allowed_attachment_types: allowed_attachment_types,
                      guardian: guardian,
                    ),
                  type: message[2].present? ? message[2].to_sym : :model,
                }

                custom_context[:id] = message[1] if custom_context[:type] != :model
                custom_context[:name] = message[3] if message[3]

                thinking = message[4]
                custom_context[:thinking] = thinking if thinking
                provider_data = message[5]
                custom_context[:provider_data] = provider_data if provider_data.is_a?(Hash)
                custom_context[:created_at] = created_at

                if custom_context[:type] == :model && remaining_upload_ids.present?
                  content_text = message_text(custom_context[:content])
                  referenced_upload_ids =
                    remaining_upload_ids.select do |upload_id|
                      upload = uploads_by_id[upload_id]
                      upload && content_text.include?(upload.short_url)
                    end
                  if referenced_upload_ids.present?
                    custom_context[:upload_ids] = referenced_upload_ids
                    remaining_upload_ids -= referenced_upload_ids
                  end
                end

                builder.push(**custom_context)
              end
            end

          if custom_prompt.present?
            custom_prompt.each(&custom_prompt_translation)
          else
            context = { content: raw, type: (bot_usernames.include?(username) ? :model : :user) }

            context[:id] = username if context[:type] == :user

            context[:upload_ids] = filtered_upload_ids
            context[:created_at] = created_at

            builder.push(**context)
          end
        end

        builder.trim_to_token_budget!(context_token_budget, tokenizer:)

        builder.prepend_scope_notice!(load_limit) if public_context && history_snapshot
        builder.to_a(style: style || (post.topic.private_message? ? :bot : :topic))
      end

      def self.recover_chat_messages(query, snapshot)
        messages = []
        bytes = 0
        coverage_boundary = nil
        loop do
          page =
            query
              .includes(:user, :uploads, :thread)
              .order(id: :desc)
              .limit(MAX_CONTEXT_MESSAGES)
              .to_a
          break if page.empty?
          prompts =
            ChatMessageCustomPrompt
              .where(message_id: page.map(&:id))
              .pluck(:message_id, :custom_prompt)
              .to_h
          if !coverage_boundary
            carrier =
              page.find do |entry|
                snapshot.authorized_evidence?(prompts[entry.id]) &&
                  usable_checkpoint(prompts[entry.id], snapshot, entry.id)
              end
            coverage_boundary =
              snapshot.covered_position(checkpoint_entry(prompts[carrier.id])[6]) if carrier
          end
          page = page.select { |entry| entry.id > coverage_boundary } if coverage_boundary
          prompts.slice!(*page.map(&:id)) if coverage_boundary
          bytes += page.sum { |entry| entry.message.to_s.bytesize } + prompts.to_json.bytesize
          if bytes > MAX_RECOVERY_BYTES
            raise ContextPreparation::Error.new("history_recovery_limit")
          end
          messages.concat(page)
          break if coverage_boundary && (page.empty? || page.last.id <= coverage_boundary + 1)
          break if page.length < MAX_CONTEXT_MESSAGES
          query = query.where("chat_messages.id < ?", page.last.id)
        end
        [messages.reverse, coverage_boundary]
      end

      def self.usable_checkpoint(entries, snapshot, carrier_position, minimum_coverage: nil)
        checkpoint = checkpoint_entry(entries)
        return false if !checkpoint || !snapshot.validate_checkpoint!(checkpoint[6])
        boundary = snapshot.covered_position(checkpoint[6])
        boundary < carrier_position && (!minimum_coverage || boundary >= minimum_coverage)
      end

      def self.checkpoint_parts(entries, snapshot)
        checkpoint = checkpoint_entry(entries)
        index = entries.index(checkpoint)
        prefix = entries[index, 2] + entries[0...index]
        remainder = entries.drop(index + 2)
        prefix << remainder.shift while remainder.first&.dig(2) == "user"
        [prefix, remainder, snapshot.covered_position(checkpoint[6])]
      end

      def self.push_checkpoint_prefix(builder, entries, **options)
        entries.each do |entry|
          next if entry[2] == "function"
          type = entry[2].present? ? entry[2].to_sym : :model
          builder.push(
            type: type,
            content: filtered_custom_prompt_content(entry[0], **options),
            id: type == :model ? nil : entry[1],
            name: entry[3],
            thinking: entry[4],
            provider_data: entry[5],
          )
        end
      end

      def self.without_checkpoint(entries)
        entries = Array(entries).dup
        while (checkpoint = checkpoint_entry(entries))
          index = entries.index(checkpoint)
          entries.slice!(index, 2)
        end
        entries
      end

      def self.without_public_requests(entries)
        entries.each_with_index.filter_map do |entry, index|
          next if entry[2] == "user"
          previous = entries[index - 1] if index > 0
          if entry[2] == "model" &&
               entry[0] == "The preceding attachments are retained historical evidence." &&
               previous&.dig(2) == "user" &&
               Array(previous[0]).first.to_s.start_with?("Retained historical attachments")
            next
          end
          entry
        end
      end

      def prepend_scope_notice!(limit)
        return if @raw_messages.empty?
        content = @raw_messages.first[:content]
        @raw_messages.first[:content] = [
          "Public context is scoped to the latest #{limit} visible source messages. Earlier public history is not included.\n",
          *Array(content),
        ]
      end

      def self.checkpoint_entry(raw_context)
        Array(raw_context)
          .each_cons(2)
          .to_a
          .reverse_each do |entry, acknowledgement|
            if entry[2] == "user" && entry[1].blank? &&
                 entry[0].to_s.start_with?(COMPRESSED_CONTEXT_PREFIX) &&
                 acknowledgement[0] == COMPRESSED_CONTEXT_ACK
              return entry
            end
          end
        nil
      end

      def self.message_text(value)
        case value
        when Hash
          message_text(value[:content] || value["content"])
        when Array
          value.map { |item| message_text(item) }.join
        else
          value.to_s
        end
      end

      # Finds the last compression checkpoint: a bot-authored :user message
      # (blank id) wrapped in the compressed context markers, acknowledged by
      # the :model message that follows it.
      def self.compression_checkpoint_index(messages)
        (messages.length - 2).downto(0) do |index|
          message = messages[index]
          next if message[:type] != :user
          next if message[:id].present?
          next if !message_text(message).start_with?(COMPRESSED_CONTEXT_PREFIX)

          next_message = messages[index + 1]
          if next_message[:type] != :model || message_text(next_message) != COMPRESSED_CONTEXT_ACK
            next
          end

          return index
        end

        nil
      end

      def self.normalize_upload_inclusion(
        include_uploads,
        include_image_uploads,
        include_document_uploads
      )
        include_image_uploads = include_uploads if include_image_uploads.nil?
        include_document_uploads = include_uploads if include_document_uploads.nil?

        [!!include_image_uploads, !!include_document_uploads]
      end

      def self.filtered_custom_prompt_content(
        content,
        include_image_uploads:,
        include_document_uploads:,
        guardian:,
        allowed_attachment_types: nil
      )
        return content if !content.is_a?(Array)

        upload_ids =
          content.filter_map { |part| part[:upload_id] || part["upload_id"] if part.is_a?(Hash) }
        allowed_upload_ids =
          filtered_upload_ids_for_prompt(
            upload_ids,
            include_image_uploads: include_image_uploads,
            include_document_uploads: include_document_uploads,
            allowed_attachment_types: allowed_attachment_types,
            guardian: guardian,
          ) || []

        content.reject do |part|
          part.is_a?(Hash) && (upload_id = part[:upload_id] || part["upload_id"]) &&
            !allowed_upload_ids.include?(upload_id.to_i)
        end
      end

      def self.filtered_upload_ids_for_prompt(
        upload_ids,
        include_image_uploads:,
        include_document_uploads:,
        guardian:,
        allowed_attachment_types: nil
      )
        return if !include_image_uploads && !include_document_uploads
        return if upload_ids.blank?

        upload_ids = Array(upload_ids).compact.map(&:to_i)
        uploads_by_id = uploads_for_prompt(upload_ids).index_by(&:id)

        filtered_upload_ids_from_uploads(
          upload_ids.filter_map { |upload_id| uploads_by_id[upload_id] },
          include_image_uploads: include_image_uploads,
          include_document_uploads: include_document_uploads,
          allowed_attachment_types: allowed_attachment_types,
          guardian: guardian,
        )
      end

      # Upload#access_control_post is deliberately wrapped in Post.unscoped so a deleted
      # post still hides its uploads; a bare includes would bypass that and expose them
      def self.uploads_for_prompt(upload_ids)
        Post.unscoped { Upload.where(id: upload_ids).includes(:access_control_post).to_a }
      end

      def self.filtered_upload_ids_from_uploads(
        uploads,
        include_image_uploads:,
        include_document_uploads:,
        guardian:,
        allowed_attachment_types: nil
      )
        return if !include_image_uploads && !include_document_uploads
        return if uploads.blank?

        uploads
          .select do |upload|
            upload_allowed_for_prompt?(
              upload,
              include_image_uploads: include_image_uploads,
              include_document_uploads: include_document_uploads,
              allowed_attachment_types: allowed_attachment_types,
              guardian: guardian,
            )
          end
          .map(&:id)
          .presence
      end

      def self.upload_allowed_for_prompt?(
        upload,
        include_image_uploads:,
        include_document_uploads:,
        guardian:,
        allowed_attachment_types: nil
      )
        type_allowed =
          if UploadEncoder.image?(upload)
            include_image_uploads && UploadEncoder.supported_image_upload?(upload)
          else
            include_document_uploads &&
              document_upload_allowed_for_prompt?(upload, allowed_attachment_types)
          end
        return false if !type_allowed

        guardian.can_see_upload?(upload)
      end

      def self.document_upload_allowed_for_prompt?(upload, allowed_attachment_types)
        allowed_attachment_types = LlmModel.normalize_attachment_types(allowed_attachment_types)
        return false if allowed_attachment_types.blank?

        mime_type =
          MiniMime.lookup_by_filename(upload.original_filename)&.content_type ||
            "application/octet-stream"
        attachment_type =
          DiscourseAi::Completions::DocumentEncoder.attachment_type_for(upload.extension, mime_type)
        allowed_attachment_types.include?(attachment_type)
      end

      def initialize
        @raw_messages = []
        @timestamps = {}
      end

      def set_chat_context_posts(
        post_ids,
        guardian,
        include_uploads: nil,
        include_image_uploads: nil,
        include_document_uploads: nil,
        allowed_attachment_types: nil
      )
        include_image_uploads, include_document_uploads =
          self.class.normalize_upload_inclusion(
            include_uploads,
            include_image_uploads,
            include_document_uploads,
          )

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
            upload_ids =
              self.class.filtered_upload_ids_from_uploads(
                post.uploads,
                include_image_uploads: include_image_uploads,
                include_document_uploads: include_document_uploads,
                allowed_attachment_types: allowed_attachment_types,
                guardian: guardian,
              )
            upload_ids&.each { |upload_id| posts_context << { upload_id: upload_id } }
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
        raw_messages = messages_after_last_compression(@raw_messages).map(&:dup)
        result = valid_messages_array(raw_messages)
        prepend_chat_post_context(result) if style == :chat_with_context

        if limit
          result[0..limit]
        else
          result
        end
      end

      def trim_to_token_budget!(token_budget, tokenizer: nil)
        token_budget = token_budget.to_i
        return if token_budget <= 0 || @raw_messages.length <= 1

        checkpoint_index = compression_checkpoint_index(@raw_messages)
        scoped_messages = checkpoint_index ? @raw_messages[checkpoint_index..] : @raw_messages
        checkpoint_messages = checkpoint_index ? scoped_messages.first(2) : []
        candidates = checkpoint_index ? scoped_messages.drop(2) : scoped_messages

        kept = []
        used_tokens =
          checkpoint_messages.sum { |message| estimate_message_tokens(message, tokenizer) }

        candidates.reverse_each do |message|
          message_tokens = estimate_message_tokens(message, tokenizer)
          # stop at the first message that does not fit so kept history stays
          # contiguous; always keep the latest message even when over budget
          break if kept.present? && used_tokens + message_tokens > token_budget

          kept << message
          used_tokens += message_tokens
        end

        @raw_messages = checkpoint_messages + kept.reverse
      end

      def push(
        type:,
        content:,
        name: nil,
        upload_ids: nil,
        id: nil,
        thinking: nil,
        created_at: nil,
        provider_data: nil
      )
        if !%i[user model tool tool_call system].include?(type)
          raise ArgumentError, "type must be either :user, :model, :tool, :tool_call or :system"
        end
        raise ArgumentError, "upload_ids must be an array" if upload_ids && !upload_ids.is_a?(Array)
        if provider_data && !provider_data.is_a?(Hash)
          raise ArgumentError, "provider_data must be a hash"
        end

        content = normalize_content_uploads(content) if content.is_a?(Array)
        content = [content, *upload_ids.map { |upload_id| { upload_id: upload_id } }] if upload_ids
        message = { type: type, content: content }
        message[:name] = name.to_s if name
        message[:id] = id.to_s if id
        message[:provider_data] = provider_data.deep_symbolize_keys if provider_data.present?
        if thinking
          if thinking.is_a?(Hash)
            thinking = thinking.deep_symbolize_keys

            if thinking[:message] || thinking[:provider_info]
              message[:thinking] = thinking[:message] if thinking[:message]
              provider_info =
                DiscourseAi::Completions::Thinking.normalize_provider_info(thinking[:provider_info])
              message[:thinking_provider_info] = provider_info if provider_info.present?
            else
              legacy_provider_info = {}
              if thinking[:thinking_signature]
                legacy_provider_info[:anthropic] ||= {}
                legacy_provider_info[:anthropic][:signature] = thinking[:thinking_signature]
              end
              if thinking[:redacted_thinking_signature]
                legacy_provider_info[:anthropic] ||= {}
                legacy_provider_info[:anthropic][:redacted_signature] = thinking[
                  :redacted_thinking_signature
                ]
              end

              message[:thinking] = thinking[:thinking] if thinking[:thinking]
              message[
                :thinking_provider_info
              ] = legacy_provider_info if legacy_provider_info.present?
            end
          else
            message[:thinking] = thinking
          end
        end

        @raw_messages << message
        @timestamps[message] = created_at if created_at

        message
      end

      private

      # Custom prompts round-trip through JSON (post_custom_prompt), which
      # turns {upload_id: 1} into {"upload_id" => 1}. Prompt#validate_message
      # only accepts the symbol-keyed form, so normalize on the way in.
      def normalize_content_uploads(content)
        content.map do |part|
          if part.is_a?(Hash) && (upload_id = part[:upload_id] || part["upload_id"])
            { upload_id: upload_id }
          else
            part
          end
        end
      end

      def estimate_message_tokens(message, tokenizer)
        text = message_text(message)
        return 0 if text.blank?

        if tokenizer
          tokenizer.size(text)
        else
          (text.bytesize / 3.0).ceil
        end
      end

      def message_text(value)
        self.class.message_text(value)
      end

      def compression_checkpoint_index(messages)
        self.class.compression_checkpoint_index(messages)
      end

      def messages_after_last_compression(messages)
        compression_index = compression_checkpoint_index(messages)

        compression_index ? messages[compression_index..] : messages
      end

      def represent_incomplete_batches(messages)
        result = []
        index = 0
        while index < messages.length
          message = messages[index]
          if !%i[tool_call tool].include?(message[:type])
            result << message
            index += 1
            next
          end
          finish = index
          finish += 1 while finish < messages.length &&
            %i[tool_call tool].include?(messages[finish][:type])
          batch = messages[index...finish]
          calls = batch.select { |entry| entry[:type] == :tool_call }.map { |entry| entry[:id] }
          outputs = batch.select { |entry| entry[:type] == :tool }.map { |entry| entry[:id] }
          complete =
            calls.present? && calls.none?(&:blank?) && outputs.none?(&:blank?) &&
              calls.uniq.length == calls.length && outputs.uniq.length == outputs.length &&
              calls.map(&:to_s).sort == outputs.map(&:to_s).sort && batch.first[:type] == :tool_call
          if complete
            result.concat(batch)
          else
            batch.each do |entry|
              details = entry.except(:content).to_json
              result << {
                type: :model,
                content: [
                  "Incomplete historical tool evidence (not executable): #{details}\n",
                  *Array(entry[:content]),
                ],
              }
            end
          end
          index = finish
        end
        result
      end

      def valid_messages_array(messages)
        messages = represent_incomplete_batches(messages) if preserve_history
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

          if !last_type && message[:type] != :user
            if preserve_history
              result << {
                type: :user,
                content:
                  "The following is retained conversation history; earlier user context is unavailable.",
              }
              last_type = :user
            else
              next
            end
          end

          if last_type == :tool_call && !%i[tool tool_call].include?(message[:type])
            raise ContextPreparation::Error.new("incomplete_tool_batch") if preserve_history
            result.pop
            last_type = result.length > 0 ? result[-1][:type] : nil
          end

          if message[:type] == :tool && !%i[tool_call tool].include?(last_type)
            raise ContextPreparation::Error.new("incomplete_tool_batch") if preserve_history
            next
          end

          if message[:type] == last_type && !%i[tool_call tool].include?(last_type)
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
            elsif preserve_history
              if last_message[:thinking_provider_info].present? ||
                   message[:thinking_provider_info].present? ||
                   last_message[:provider_data].present? || message[:provider_data].present?
                result << {
                  type: :user,
                  content: "Continuation of the assistant response follows.",
                }
                result << message
                last_type = message[:type]
                next
              end
              last_message[:content] = compress_messages_buffer(
                [last_message[:content], "\n", message[:content]].flatten,
                max_uploads: MAX_TOPIC_UPLOADS,
              )
              thinking = [last_message[:thinking], message[:thinking]].compact.join("\n")
              last_message[:thinking] = thinking if thinking.present?
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
        raw_messages = messages_after_last_compression(@raw_messages.dup)
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

        history = []
        if preserve_history && raw_messages.present?
          history << {
            type: :user,
            content:
              compress_messages_buffer(content_array.flatten, max_uploads: MAX_TOPIC_UPLOADS),
          }
          content_array = []
        end

        if last_user_message
          content_array << "Latest post is by #{last_user_message[:id] || "User"} who just posted:\n"
          content_array << last_user_message[:content]
        end

        content_array =
          compress_messages_buffer(content_array.flatten, max_uploads: MAX_TOPIC_UPLOADS)

        user_message = { type: :user, content: content_array }

        [*history, user_message]
      end

      def chat_array(limit:)
        raw_messages = messages_after_last_compression(@raw_messages)
        buffer = []
        if raw_messages.length > 1
          buffer << +"You are replying inside a Discourse chat channel. Here is a summary of the conversation so far:\n{{{"

          raw_messages[0..-2].each do |message|
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

        last_message = raw_messages[-1]
        history = []
        if preserve_history && raw_messages.length > 1
          history << {
            type: :user,
            content: compress_messages_buffer(buffer.flatten, max_uploads: MAX_CHAT_UPLOADS),
          }
          buffer = []
        end
        buffer << "#{last_message[:id] || "User"}: "
        buffer << last_message[:content]

        buffer = compress_messages_buffer(buffer.flatten, max_uploads: MAX_CHAT_UPLOADS)

        message = { type: :user, content: buffer }
        [*history, message]
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

        if !preserve_history && upload_count > max_uploads
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
