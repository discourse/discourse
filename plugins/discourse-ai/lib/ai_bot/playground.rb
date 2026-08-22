# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Playground
      BYPASS_AI_REPLY_CUSTOM_FIELD = "discourse_ai_bypass_ai_reply"
      BOT_USER_PREF_ID_CUSTOM_FIELD = "discourse_ai_bot_user_pref_id"
      # 10 minutes is enough for vast majority of cases
      # there is a small chance that some reasoning models may take longer
      MAX_STREAM_DELAY_SECONDS = 600
      FALLBACK_TITLE_LENGTH = 80

      attr_reader :bot

      # An abstraction to manage the bot and topic interactions.
      # The bot will take care of completions while this class updates the topic title
      # and stream replies.

      def self.find_chat_agent(message, channel, user)
        if channel.direct_message_channel?
          AiAgent
            .allowed_modalities(allow_chat_direct_messages: true)
            .find do |p|
              p[:user_id].in?(channel.allowed_user_ids) && (user.group_ids & p[:allowed_group_ids])
            end
        else
          # let's defer on the parse if there is no @ in the message
          if message.message.include?("@")
            mentions = message.parsed_mentions.parsed_direct_mentions
            if mentions.present?
              AiAgent
                .allowed_modalities(allow_chat_channel_mentions: true)
                .find { |p| p[:username].in?(mentions) && (user.group_ids & p[:allowed_group_ids]) }
            end
          end
        end
      end

      def self.schedule_chat_reply(message, channel, user, context)
        return if !SiteSetting.ai_bot_enabled

        all_chat =
          AiAgent.allowed_modalities(
            allow_chat_channel_mentions: true,
            allow_chat_direct_messages: true,
          )
        return if all_chat.blank?
        return if all_chat.any? { |m| m[:user_id] == user.id }

        agent = find_chat_agent(message, channel, user)
        return if !agent

        post_ids = nil
        post_ids = context.dig(:context, :post_ids) if context.is_a?(Hash)

        ::Jobs.enqueue(
          :create_ai_chat_reply,
          channel_id: channel.id,
          message_id: message.id,
          agent_id: agent[:id],
          context_post_ids: post_ids,
        )
      end

      def self.is_bot_user_id?(user_id)
        # this will catch everything and avoid any feedback loops
        # we could get feedback loops between say discobot and ai-bot or third party plugins
        # and bots
        user_id.to_i <= 0
      end

      def self.get_bot_user(post:, all_llm_users:, mentionables:)
        bot_user = nil
        if post.topic.private_message?
          # this ensures that we reply using the correct llm
          # 1. if we have a preferred llm user we use that
          # 2. if we don't just take first topic allowed user
          # 3. if we don't have that we take the first mentionable
          bot_user = nil
          if preferred_user =
               all_llm_users.find { |id, username|
                 id == post.topic.custom_fields[BOT_USER_PREF_ID_CUSTOM_FIELD].to_i
               }
            bot_user = User.find_by(id: preferred_user[0])
          end
          bot_user ||=
            post.topic.topic_allowed_users.where(user_id: all_llm_users.map(&:first)).first&.user
          bot_user ||=
            post
              .topic
              .topic_allowed_users
              .where(user_id: mentionables.map { |m| m[:user_id] })
              .first
              &.user
        end
        bot_user
      end

      def self.schedule_reply(post)
        if is_bot_user_id?(post.user_id)
          # Rule 4: an AI's post may also summon via Rule 2, but only as a
          # single hop directly after a human post. This lets a model that
          # mentions another agent in its answer (e.g. "I'll ask @ai_x to
          # regenerate") actually trigger it, while preventing bot->bot
          # chains and feedback loops.
          previous =
            post.topic.posts.where("post_number < ?", post.post_number).order(:post_number).last
          return if previous.nil? || is_bot_user_id?(previous.user_id)
        end
        mentionables = nil

        if post.topic.private_message?
          mentionables = AiAgent.allowed_modalities(user: post.user, allow_personal_messages: true)
        else
          mentionables = AiAgent.allowed_modalities(user: post.user, allow_topic_mentions: true)
        end

        mentioned = nil

        all_llm_users =
          LlmModel
            .where(id: LlmModel.enabled_chat_bot_ids)
            .joins(:user)
            .pluck("users.id", "users.username_lower")

        bot_user =
          get_bot_user(post: post, all_llm_users: all_llm_users, mentionables: mentionables)

        mentions = nil
        if mentionables.present? || (bot_user && post.topic.private_message?)
          mentions = explicit_mentions(post)
        end

        if mentionables.present?
          # Rule 2: the FIRST explicitly mentioned agent (typing order) wins.
          # Only one responder, ever.
          mentionables_by_username = mentionables.index_by { |m| m[:username] }
          mentioned = mentions.lazy.filter_map { |username| mentionables_by_username[username] }.first

          # PMs keep the stock dynamic: a bot invited to the conversation may
          # answer messages that do not mention it (Rule 3 applies to public
          # topics only).
          if !mentioned && post.topic.private_message? && bot_user
            mentioned = mentionables.find { |mentionable| bot_user.id == mentionable[:user_id] }
          end

          # public topic so we need to use the agent user
          bot_user ||= User.find_by(id: mentioned[:user_id]) if mentioned
        end

        # Rule 3: no proactive replies in public topics — explicit mentions are
        # the only trigger.
        return if !mentioned && !post.topic.private_message?

        if !mentioned && bot_user && post.reply_to_post_number && !post.reply_to_post.user&.bot?
          # replying to a non-bot user (PM)
          return
        end

        if bot_user
          topic_agent_id = post.topic.custom_fields["ai_agent_id"]
          topic_agent_id = topic_agent_id.to_i if topic_agent_id.present?

          authorization_user = post.user
          if mentioned
            agent_id = mentioned[:id]
          else
            agent_id = topic_agent_id
            authorization_user = post.topic.user if topic_agent_id
          end

          agent = nil

          agent =
            DiscourseAi::Agents::Agent.find_by(
              user: authorization_user,
              id: agent_id.to_i,
            ) if agent_id && authorization_user

          if !agent && (agent_name = post.topic.custom_fields["ai_agent"])
            authorization_user = post.topic.user
            agent =
              DiscourseAi::Agents::Agent.find_by(
                user: authorization_user,
                name: agent_name,
              ) if authorization_user
          end

          # edge case, llm was mentioned in an ai agent conversation
          if agent_id == topic_agent_id && post.topic.private_message? && agent &&
               all_llm_users.present?
            if !agent.force_default_llm && mentions.present?
              mentioned_llm_user_id, _ =
                all_llm_users.find { |id, username| mentions.include?(username) }

              if mentioned_llm_user_id
                bot_user = User.find_by(id: mentioned_llm_user_id) || bot_user
              end
            end
          end

          if !agent
            agent = DiscourseAi::Agents::General
            authorization_user = post.user
          end

          bot_user = User.find(agent.user_id) if agent && agent.force_default_llm

          # dedup guard: one post -> at most one enqueued AI request
          return if !Discourse.redis.set("ai_reply_dedup:#{post.id}", "1", nx: true, ex: 600)

          bot = DiscourseAi::Agents::Bot.as(bot_user, agent: agent.new)
          new(bot).update_playground_with(post, authorization_user: authorization_user)
        end
      end

      def self.explicit_mentions(post)
        # Mentions the user actually typed, excluding [quote] blocks and
        # preserving typing order (Rule 2).
        raw = post.raw.to_s.gsub(/\[quote[^\]]*\].*?\[\/quote\]/m, " ")
        raw
          .scan(/(?:^|[\s(>])@([a-zA-Z0-9_.-]+)/)
          .flatten
          .map(&:downcase)
          .uniq
      end

      def self.reply_to_post(
        post:,
        user: nil,
        agent_id: nil,
        whisper: nil,
        add_user_to_pm: false,
        stream_reply: false,
        auto_set_title: false,
        silent_mode: false,
        feature_name: nil,
        attributed_user: nil,
        feature_context: nil
      )
        ai_agent = AiAgent.find_by(id: agent_id)
        raise Discourse::InvalidParameters.new(:agent_id) if !ai_agent
        agent_class = ai_agent.class_instance
        agent = agent_class.new

        bot_user = user || ai_agent.user
        raise Discourse::InvalidParameters.new(:user) if bot_user.nil?
        bot = DiscourseAi::Agents::Bot.as(bot_user, agent: agent)
        playground = new(bot)

        playground.reply_to(
          post,
          whisper: whisper,
          context_style: :topic,
          add_user_to_pm: add_user_to_pm,
          stream_reply: stream_reply,
          auto_set_title: auto_set_title,
          silent_mode: silent_mode,
          feature_name: feature_name,
          attributed_user: attributed_user,
          feature_context: feature_context,
        )
      rescue => e
        raise e
      end

      def initialize(bot)
        @bot = bot
      end

      def update_playground_with(post, authorization_user: post.user)
        schedule_bot_reply(post, authorization_user: authorization_user) if can_attach?(post)
      end

      def title_playground(post, user)
        messages =
          DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
            post,
            max_posts: 5,
            bot_usernames: available_bot_usernames,
            include_image_uploads: include_image_uploads?,
            include_document_uploads: include_document_uploads?,
            allowed_attachment_types: bot.model.allowed_attachment_types,
          )

        # conversation context may contain tool calls, and confusing user names
        # clean it up
        conversation = +""
        messages.each do |context|
          if context[:type] == :user
            conversation << "User said:\n#{context[:content]}\n\n"
          elsif context[:type] == :model
            conversation << "Model said:\n#{context[:content]}\n\n"
          end
        end

        system_insts = <<~TEXT.strip
          You are titlebot. Given a conversation, you will suggest a title.

          - You will never respond with anything but the suggested title.
          - You will always match the conversation language in your title suggestion.
          - Title will capture the essence of the conversation.
        TEXT

        instruction = <<~TEXT.strip
          Given the following conversation:

          {{{
          #{conversation}
          }}}

          Reply only with a title that is 7 words or less.
        TEXT

        title_prompt =
          DiscourseAi::Completions::Prompt.new(
            system_insts,
            messages: [type: :user, content: instruction],
            topic_id: post.topic_id,
          )

        new_title =
          DiscourseAi::Completions::Llm.text_from_response(
            bot.llm.generate(title_prompt, user: user, feature_name: "bot_title"),
          )
        new_title = new_title.to_s.strip.split("\n").last.to_s
        new_title = new_title.delete_prefix('"').delete_suffix('"')

        first_post = post.topic.first_post

        if new_title.blank?
          new_title =
            PrettyText.excerpt(
              first_post.cooked,
              FALLBACK_TITLE_LENGTH,
              strip_links: true,
              text_entities: true,
            )
        end

        return if new_title.blank?

        new_title = new_title.truncate(SiteSetting.max_topic_title_length, separator: /\s/)

        revised =
          PostRevisor.new(first_post, post.topic).revise!(
            bot.bot_user,
            { title: new_title },
            bypass_rate_limiter: true,
          )

        return if !revised

        allowed_users = post.topic.topic_allowed_users.pluck(:user_id)
        MessageBus.publish(
          "/discourse-ai/ai-bot/topic/#{post.topic.id}",
          { title: post.topic.title },
          user_ids: allowed_users,
        )
        MessageBus.publish(
          "/discourse-ai/ai-bot/topic-titles",
          { title: post.topic.title, topic_id: post.topic.id },
          user_ids: allowed_users,
        )
      rescue StandardError => e
        Discourse.warn_exception(e, message: "Discourse AI: Unable to generate title")
      end

      def reply_to_chat_message(message, channel, context_post_ids)
        agent_user = User.find(bot.agent.class.user_id)

        participants = channel.user_chat_channel_memberships.map { |m| m.user.username }

        context_post_ids = nil if !channel.direct_message_channel?

        if !channel.direct_message_channel?
          # we are interacting via mentions ... strip mention
          instruction_message = message.message.gsub(/@#{bot.bot_user.username}/i, "").strip
        end

        context_llm = bot.llm
        context =
          DiscourseAi::Agents::BotContext.new(
            participants: participants,
            message_id: message.id,
            channel_id: channel.id,
            context_post_ids: context_post_ids,
            messages:
              DiscourseAi::Completions::PromptMessagesBuilder.messages_from_chat(
                message,
                channel: channel,
                context_post_ids: context_post_ids,
                include_image_uploads: include_image_uploads?,
                include_document_uploads: include_document_uploads?,
                allowed_attachment_types: bot.model.allowed_attachment_types,
                max_messages: DiscourseAi::Completions::PromptMessagesBuilder::MAX_CONTEXT_MESSAGES,
                context_token_budget: context_token_budget(context_llm),
                tokenizer: context_llm.tokenizer,
                bot_user_ids: available_bot_user_ids,
                instruction_message: instruction_message,
              ),
            user: message.user,
            skip_show_thinking: true,
            cancel_manager: DiscourseAi::Completions::CancelManager.new,
          )

        reply = nil
        guardian = Guardian.new(agent_user)

        force_thread = message.thread_id.nil? && channel.direct_message_channel?
        in_reply_to_id = channel.direct_message_channel? ? message.id : nil

        streamer =
          ChatStreamer.new(
            message: message,
            channel: channel,
            guardian: guardian,
            thread_id: message.thread_id,
            in_reply_to_id: in_reply_to_id,
            force_thread: force_thread,
            cancel_manager: context.cancel_manager,
          )

        pending_approvals = []
        new_prompts =
          bot.reply(context) do |partial, placeholder, type|
            # no support for thinking by design
            next if type == :thinking || type == :partial_tool
            if type == :chat_approval
              pending_approvals << partial
              next
            end
            streamer << partial
          end

        reply = streamer.reply
        if new_prompts.length > 1 && reply
          # Note: messages_from_chat does not read these back, so compressed
          # context checkpoints only persist across turns for post-based
          # replies; chat rebuilds context from the raw messages each turn.
          ChatMessageCustomPrompt.create!(message_id: reply.id, custom_prompt: new_prompts)
        end

        if streamer
          streamer.done
          streamer = nil
        end

        pending_approvals.each do |pending_approval|
          post_chat_tool_approval(
            pending_approval,
            channel: channel,
            guardian: guardian,
            thread_id: reply&.thread_id || message.reload.thread_id,
            fallback_in_reply_to_id: message.id,
          )
        end

        reply
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        if streamer && streamer.instance_variable_get(:@client_id)
          ChatSDK::Channel.stop_reply(
            channel_id: channel.id,
            client_id: streamer.instance_variable_get(:@client_id),
            guardian: guardian,
            thread_id: message.thread_id,
          )
        end

        reset_time = e.allocation&.formatted_reset_time || ""
        locale_key = message.user.admin? ? "limit_exceeded_admin" : "limit_exceeded_user"
        error_message =
          I18n.t("discourse_ai.llm_credit_allocation.#{locale_key}", reset_time: reset_time)

        # Convert HTML links to markdown format for chat
        error_message =
          error_message.gsub(%r{<a\s+href=['"]([^'"]+)['"][^>]*>([^<]+)</a>}i, '[\2](\1)')

        ChatSDK::Message.create(
          raw: error_message,
          channel_id: channel.id,
          guardian: guardian,
          thread_id: message.thread_id,
          in_reply_to_id: in_reply_to_id,
          force_thread: force_thread,
          enforce_membership: !channel.direct_message_channel?,
        )

        nil
      ensure
        streamer.done if streamer
      end

      # Posts the queued tool action as its own chat message carrying the
      # Approve/Reject blocks, in the same thread as the bot's reply so it sits
      # with the conversation. It must be a fresh message (not an edit of the
      # reply): the chat client only renders blocks present at message creation.
      # Scoped to bot direct-message channels; elsewhere the reviewable is still
      # created and remains actionable from /review.
      def post_chat_tool_approval(info, channel:, guardian:, thread_id:, fallback_in_reply_to_id:)
        return if !channel.direct_message_channel?

        raw = +"**#{info[:summary]}**\n#{info[:details]}".strip
        raw << "\n\n_#{I18n.t("discourse_ai.ai_bot.tool_pending_approval")}_"

        ChatSDK::Message.create(
          raw: raw,
          channel_id: channel.id,
          guardian: guardian,
          thread_id: thread_id,
          in_reply_to_id: thread_id ? nil : fallback_in_reply_to_id,
          force_thread: thread_id.blank?,
          enforce_membership: !channel.direct_message_channel?,
          blocks: DiscourseAi::AiBot::ChatToolApproval.pending_blocks(info[:reviewable_id]),
        )
      end

      def reply_to(
        post,
        custom_instructions: nil,
        whisper: nil,
        context_style: nil,
        add_user_to_pm: true,
        stream_reply: nil,
        auto_set_title: true,
        silent_mode: false,
        feature_name: nil,
        existing_reply_post: nil,
        cancel_manager: nil,
        attributed_user: nil,
        feature_context: nil,
        authorization_user_id: nil,
        &blk
      )
        # this is a multithreading issue
        # post custom prompt is needed and it may not
        # be properly loaded, ensure it is loaded
        PostCustomPrompt.none

        if silent_mode
          auto_set_title = false
          stream_reply = false
        end

        reply = +""
        post_streamer = nil
        stream_user_ids = nil
        stream_group_ids = nil

        post_type =
          (
            if whisper || post.post_type == Post.types[:whisper]
              Post.types[:whisper]
            else
              Post.types[:regular]
            end
          )

        context_llm = bot.llm
        context =
          DiscourseAi::Agents::BotContext.new(
            post: post,
            user: attributed_user,
            custom_instructions: custom_instructions,
            feature_name: feature_name,
            feature_context: feature_context,
            messages:
              DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
                post,
                style: context_style,
                max_posts: DiscourseAi::Completions::PromptMessagesBuilder::MAX_CONTEXT_MESSAGES,
                context_token_budget: context_token_budget(context_llm),
                tokenizer: context_llm.tokenizer,
                include_image_uploads: include_image_uploads?,
                include_document_uploads: include_document_uploads?,
                allowed_attachment_types: bot.model.allowed_attachment_types,
                bot_usernames: available_bot_usernames,
              ),
          )

        reply_user = bot.bot_user
        if bot.agent.class.respond_to?(:user_id)
          reply_user = User.find_by(id: bot.agent.class.user_id) || reply_user
        end

        if existing_reply_post
          if existing_reply_post.topic_id != post.topic_id
            raise Discourse::InvalidParameters.new(:reply_post_id)
          end

          if existing_reply_post.user_id != reply_user.id
            raise Discourse::InvalidParameters.new(:reply_post_id)
          end
        end

        stream_reply = post.topic.private_message? if stream_reply.nil?

        # we need to ensure agent user is allowed to reply to the pm
        if post.topic.private_message? && add_user_to_pm
          if !post.topic.topic_allowed_users.exists?(user_id: reply_user.id)
            post.topic.topic_allowed_users.create!(user_id: reply_user.id)
          end
          # edge case, maybe the llm user is missing?
          if !post.topic.topic_allowed_users.exists?(user_id: bot.bot_user.id)
            post.topic.topic_allowed_users.create!(user_id: bot.bot_user.id)
          end

          # we store the id of the last bot_user, this is then used to give it preference
          if post.topic.custom_fields[BOT_USER_PREF_ID_CUSTOM_FIELD].to_i != bot.bot_user.id
            post.topic.custom_fields[BOT_USER_PREF_ID_CUSTOM_FIELD] = bot.bot_user.id
            post.topic.save_custom_fields
          end
        end

        if stream_reply
          reply_post = existing_reply_post

          if reply_post
            reply_post.update_columns(raw: "", cooked: "")
            reply_post.post_custom_prompt = nil
          else
            reply_post =
              PostCreator.create!(
                reply_user,
                topic_id: post.topic_id,
                reply_to_post_number: post.reply_to_post_number,
                raw: "",
                skip_validations: true,
                skip_jobs: true,
                post_type: post_type,
                skip_guardian: true,
                custom_fields: ai_custom_fields(authorization_user_id: authorization_user_id),
              )
          end

          save_ai_custom_fields(reply_post, authorization_user_id: authorization_user_id)

          stream_user_ids = reply_post.topic.allowed_users.pluck(:id)
          stream_group_ids = reply_post.topic.allowed_groups.pluck(:id)

          publish_update(
            reply_post,
            payload: {
              raw: "",
            },
            user_ids: stream_user_ids,
            group_ids: stream_group_ids,
          )

          redis_stream_key = "gpt_cancel:#{reply_post.id}"
          Discourse.redis.setex(redis_stream_key, MAX_STREAM_DELAY_SECONDS, 1)

          cancel_manager ||= DiscourseAi::Completions::CancelManager.new
          context.cancel_manager = cancel_manager
          context
            .cancel_manager
            .start_monitor(delay: 0.2) do
              context.cancel_manager.cancel! if !Discourse.redis.get(redis_stream_key)
            end

          context.cancel_manager.add_callback(
            lambda { reply_post.update!(raw: reply, cooked: PrettyText.cook(reply)) },
          )
        end

        context.skip_show_thinking ||= !bot.agent.class.show_thinking
        post_streamer = PostStreamer.new(delay: Rails.env.test? ? 0 : 0.5) if stream_reply
        started_thinking = false

        new_custom_prompts =
          bot.reply(context) do |partial, placeholder, type|
            if context.skip_show_thinking && %i[thinking partial_tool partial_invoke].include?(type)
              next
            end
            next if type == :structured_output && !partial.finished?

            if should_start_thinking?(partial:, context:, type:, started_thinking:, placeholder:)
              reply << "\n\n" if reply.present? && !reply.end_with?("\n")
              reply << "<details class='ai-thinking'><summary>#{I18n.t("discourse_ai.ai_bot.thinking")}</summary>\n\n"
              started_thinking = true
            elsif should_stop_thinking?(partial:, context:, type:, started_thinking:, placeholder:)
              reply << "\n" if !reply.end_with?("\n")
              reply << "</details>\n\n"
              started_thinking = false
            end

            if type == :thinking && partial.present? && placeholder.blank? && started_thinking &&
                 !reply.end_with?("\n")
              reply << "\n\n"
            end

            reply << partial
            raw = reply.dup
            raw << "\n\n" << placeholder if placeholder.present?

            if blk && type != :thinking && type != :partial_tool && type != :partial_invoke
              blk.call(partial)
            end

            if post_streamer
              post_streamer.run_later do
                Discourse.redis.expire(redis_stream_key, MAX_STREAM_DELAY_SECONDS)
                publish_update(
                  reply_post,
                  payload: {
                    raw: raw,
                  },
                  user_ids: stream_user_ids,
                  group_ids: stream_group_ids,
                )
              end
            end
          end

        return if reply.blank? || silent_mode

        if started_thinking
          reply << "\n\n</details>"
          started_thinking = false
        end

        if stream_reply
          post_streamer.finish
          post_streamer = nil

          # land the final message prior to saving so we don't clash
          reply_post.cooked = PrettyText.cook(reply)
          publish_final_update(reply_post, user_ids: stream_user_ids, group_ids: stream_group_ids)

          reply_post.revise(
            bot.bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )
        elsif existing_reply_post
          reply_post = existing_reply_post
          reply_post.post_custom_prompt = nil
          reply_post.revise(
            bot.bot_user,
            { raw: reply },
            skip_validations: true,
            force_new_version: true,
            bypass_rate_limiter: true,
          )
          save_ai_custom_fields(reply_post, authorization_user_id: authorization_user_id)
        else
          reply_post =
            PostCreator.create!(
              reply_user,
              topic_id: post.topic_id,
              reply_to_post_number: post.reply_to_post_number,
              raw: reply,
              skip_validations: true,
              post_type: post_type,
              skip_guardian: true,
              custom_fields: ai_custom_fields(authorization_user_id: authorization_user_id),
            )
        end

        # a bit messy internally, but this is how we tell
        is_thinking = new_custom_prompts.any? { |prompt| prompt[4].present? }

        if is_thinking || new_custom_prompts.length > 1
          reply_post.post_custom_prompt ||= reply_post.build_post_custom_prompt(custom_prompt: [])
          prompt = reply_post.post_custom_prompt.custom_prompt || []
          prompt.concat(new_custom_prompts)
          reply_post.post_custom_prompt.update!(custom_prompt: prompt)
        end

        reply_post
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        return if silent_mode

        reset_time = e.allocation&.formatted_reset_time || ""
        locale_key = post.user.admin? ? "limit_exceeded_admin" : "limit_exceeded_user"
        error_message =
          I18n.t("discourse_ai.llm_credit_allocation.#{locale_key}", reset_time: reset_time)

        if reply_post
          reply = "#{reply}#{started_thinking ? "\n\n</details>" : ""}\n\n#{error_message}"
          reply_post.revise(
            bot.bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )
        else
          PostCreator.create!(
            bot.bot_user,
            topic_id: post.topic_id,
            reply_to_post_number: post.reply_to_post_number,
            raw: error_message,
            skip_validations: true,
            skip_guardian: true,
            custom_fields: ai_custom_fields(authorization_user_id: authorization_user_id),
          )
        end

        nil
      rescue => e
        if reply_post
          details = e.message.to_s
          reply =
            "#{reply}#{started_thinking ? "\n\n</details>" : ""}\n\n#{I18n.t("discourse_ai.ai_bot.reply_error", details: details)}"
          reply_post.revise(
            bot.bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )
        end
        raise e
      ensure
        context.cancel_manager.stop_monitor if context&.cancel_manager

        # since we are skipping validations and jobs we
        # may need to fix participant count
        if reply_post && reply_post.topic && reply_post.topic.private_message? &&
             reply_post.topic.participant_count < 2
          reply_post.topic.update!(participant_count: 2)
        end
        post_streamer&.finish(skip_callback: true)
        if stream_reply
          publish_final_update(reply_post, user_ids: stream_user_ids, group_ids: stream_group_ids)
        end
        if reply_post && post.post_number == 1 && post.topic.private_message? && auto_set_title
          title_playground(reply_post, post.user)
        end
      end

      def context_token_budget(llm)
        DiscourseAi::Agents::Bot.context_token_budget(llm, bot.agent.class.max_turn_tokens)
      end

      def available_bot_usernames
        @bot_usernames ||=
          AiAgent.joins(:user).pluck(:username).concat(available_bot_users.map(&:username))
      end

      def available_bot_user_ids
        @bot_ids ||= AiAgent.joins(:user).pluck("users.id").concat(available_bot_users.map(&:id))
      end

      def include_image_uploads?
        bot.agent.class.vision_enabled
      end

      def include_document_uploads?
        bot.model.allowed_attachment_types.present?
      end

      private

      def ai_custom_fields(authorization_user_id: nil)
        fields = {
          DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => bot.llm.llm_model.display_name,
          DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => bot.llm.llm_model.id,
          DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => bot.agent.id,
        }
        if authorization_user_id
          fields[
            DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD
          ] = authorization_user_id
        end
        fields
      end

      def save_ai_custom_fields(reply_post, authorization_user_id: nil)
        reply_post.custom_fields.merge!(ai_custom_fields(authorization_user_id:))
        reply_post.save_custom_fields
      end

      def should_stop_thinking?(partial:, context:, type:, started_thinking:, placeholder:)
        return false if context.skip_show_thinking
        return false if !started_thinking
        return false if partial.blank? && placeholder.blank?
        return true if type.nil? || type == :structured_output || type == :custom_raw

        false
      end

      def should_start_thinking?(partial:, context:, type:, started_thinking:, placeholder:)
        return false if context.skip_show_thinking
        return false if started_thinking
        return false if partial.blank? && placeholder.blank?
        return false if type.nil? || type == :structured_output || type == :custom_raw

        true
      end

      def available_bot_users
        @available_bots ||=
          User.joins("INNER JOIN llm_models llm ON llm.user_id = users.id").where(active: true)
      end

      def publish_final_update(reply_post, user_ids:, group_ids:)
        return if @published_final_update
        if reply_post
          publish_update(
            reply_post,
            payload: {
              cooked: reply_post.cooked,
              done: true,
            },
            user_ids: user_ids,
            group_ids: group_ids,
          )
          # we subscribe at position -2 so we will always get this message
          # moving all cooked on every page load is wasteful ... this means
          # we have a benign message at the end, 2 is set to ensure last message
          # is delivered
          publish_update(
            reply_post,
            payload: {
              noop: true,
            },
            user_ids: user_ids,
            group_ids: group_ids,
          )
          @published_final_update = true
        end
      end

      def can_attach?(post)
        return false if bot.bot_user.nil?
        return false if post.topic.private_message? && post.post_type != Post.types[:regular]
        return false if (SiteSetting.ai_bot_allowed_groups_map & post.user.group_ids).blank?
        return false if post.custom_fields[BYPASS_AI_REPLY_CUSTOM_FIELD].present?

        true
      end

      def schedule_bot_reply(post, authorization_user: post.user)
        agent_id = DiscourseAi::Agents::Agent.system_agents[bot.agent.class] || bot.agent.class.id
        ::Jobs.enqueue(
          :create_ai_reply,
          post_id: post.id,
          bot_user_id: bot.bot_user.id,
          agent_id: agent_id,
          authorization_user_id: authorization_user&.id,
        )
      end

      def context(topic)
        {
          site_url: Discourse.base_url,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          time: Time.zone.now,
          participants: topic.allowed_users.map(&:username).join(", "),
        }
      end

      def publish_update(bot_reply_post, payload:, user_ids:, group_ids:)
        return if user_ids.blank? && group_ids.blank?

        payload = { post_id: bot_reply_post.id, post_number: bot_reply_post.post_number }.merge(
          payload,
        )

        MessageBus.publish(
          "discourse-ai/ai-bot/topic/#{bot_reply_post.topic_id}",
          payload,
          user_ids: user_ids.presence,
          group_ids: group_ids.presence,
          max_backlog_size: 2,
          max_backlog_age: MAX_STREAM_DELAY_SECONDS,
        )
      end
    end
  end
end
