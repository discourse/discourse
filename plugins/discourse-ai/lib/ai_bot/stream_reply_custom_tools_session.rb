# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class StreamReplyCustomToolsSession
      RESUME_STATE_PREFIX = "discourse_ai:stream_reply:custom_tools:"
      RESUME_STATE_TTL_SECONDS = 15.minutes.to_i
      MAX_RESUME_ROUNDS = 10
      MAX_REDIS_STATE_BYTES = 500 * 1024

      class ProtocolError < StandardError
      end

      class ResumeTokenNotFound < ProtocolError
      end

      class InvalidToolResults < ProtocolError
      end

      def self.resume_state_exists?(resume_token)
        return false if resume_token.blank?
        Discourse.redis.exists?(redis_key(resume_token))
      end

      def self.redis_key(resume_token)
        "#{RESUME_STATE_PREFIX}#{resume_token}"
      end

      def initialize(
        persona:,
        user:,
        topic:,
        query:,
        custom_instructions:,
        current_user:,
        custom_tools:,
        resume_token:,
        tool_results:
      )
        @persona = persona
        @user = user
        @topic = topic
        @query = query
        @custom_instructions = custom_instructions
        @current_user = current_user
        @custom_tools = custom_tools || []
        @resume_token = resume_token
        @tool_results = Array(tool_results).map(&:stringify_keys)
        @accumulated_reply = +""
        @round_count = 0
      end

      def run(&event_blk)
        if resuming?
          load_resume_state!
          apply_tool_results!
        else
          setup_initial_request!
        end

        event_blk.call(
          :context,
          { topic_id: @topic.id, bot_user_id: @reply_user.id, persona_id: @persona.id },
        )

        run_single_completion_round!(&event_blk)
      end

      private

      def resuming?
        @resume_token.present?
      end

      def setup_initial_request!
        post_params = {
          raw: @query,
          skip_validations: true,
          custom_fields: {
            DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
          },
        }

        if @topic
          post_params[:topic_id] = @topic.id
        else
          post_params[:title] = I18n.t("discourse_ai.ai_bot.default_pm_prefix")
          post_params[:archetype] = Archetype.private_message
          post_params[:target_usernames] = "#{@user.username},#{@persona.user.username}"
        end

        @source_post = PostCreator.create!(@user, post_params)
        @topic = @source_post.topic
        @source_post_number = @source_post.post_number

        persona_class = DiscourseAi::Personas::Persona.find_by(id: @persona.id, user: @current_user)
        raise ProtocolError, I18n.t("discourse_ai.errors.persona_not_found") if persona_class.nil?

        @bot = DiscourseAi::Personas::Bot.as(@persona.user, persona: persona_class.new)
        @reply_user = @bot.bot_user
        @llm_model_id = @bot.model.id

        max_context_posts = @bot.persona.class.max_context_posts || 40
        context =
          DiscourseAi::Personas::BotContext.new(
            post: @source_post,
            user: @user,
            custom_instructions: @custom_instructions,
            messages:
              DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
                @source_post,
                max_posts: max_context_posts,
                include_uploads: @bot.persona.class.vision_enabled,
                bot_usernames: available_bot_usernames,
              ),
          )

        @prompt = @bot.persona.craft_prompt(context, llm: @bot.llm)
        # This endpoint supports caller-owned tool execution. We replace persona tools so every
        # emitted tool call can be completed through the resume protocol.
        @prompt.tools =
          @custom_tools.map do |tool|
            DiscourseAi::Completions::ToolDefinition.from_hash(tool.deep_symbolize_keys)
          end
        @temperature = @bot.persona.temperature
        @top_p = @bot.persona.top_p
      end

      def load_resume_state!
        payload = resume_payload
        if payload.blank?
          raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
        end

        saved_current_user_id = payload["current_user_id"]
        if saved_current_user_id.blank? || @current_user.blank? ||
             @current_user.id != saved_current_user_id
          raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
        end

        @persona = AiPersona.find(payload["persona_id"])
        @user = User.find(payload["user_id"])
        @topic = Topic.find(payload["topic_id"])
        @reply_user = User.find(payload["reply_user_id"])
        @llm_model_id = payload["llm_model_id"]
        @source_post_number = payload["source_post_number"]
        @temperature = payload["temperature"]
        @top_p = payload["top_p"]
        @accumulated_reply = payload["accumulated_reply"].to_s
        @expected_tool_calls = payload["expected_tool_calls"] || []
        @round_count = payload["round_count"].to_i

        @prompt = prompt_from_payload(payload.fetch("prompt"))
      rescue ActiveRecord::RecordNotFound
        raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
      end

      def run_single_completion_round!
        llm = DiscourseAi::Completions::Llm.proxy(@llm_model_id)
        turn_reply = +""
        streamed_tool_calls = []

        result =
          llm.generate(@prompt, user: @user, temperature: @temperature, top_p: @top_p) do |partial|
            if partial.is_a?(String)
              next if partial.empty?

              turn_reply << partial
              yield(:partial, partial)
            elsif partial.is_a?(DiscourseAi::Completions::ToolCall) && !partial.partial?
              streamed_tool_calls << partial.dup
            end
          end

        @accumulated_reply << turn_reply
        normalized_result = normalize_result(result)
        tool_calls = unique_tool_calls(streamed_tool_calls + extract_tool_calls(normalized_result))

        if tool_calls.present?
          non_tool_result =
            normalized_result.reject do |item|
              item.is_a?(DiscourseAi::Completions::ToolCall) && !item.partial?
            end

          if non_tool_result.present?
            @prompt.push_model_response(
              non_tool_result.length == 1 ? non_tool_result.first : non_tool_result,
            )
          end
        elsif normalized_result.present?
          @prompt.push_model_response(
            normalized_result.length == 1 ? normalized_result.first : normalized_result,
          )
        end

        if tool_calls.present?
          token = persist_state!(tool_calls: tool_calls)
          yield(
            :tool_calls,
            {
              event: "tool_calls",
              tool_calls: serialize_tool_calls(tool_calls),
              resume_token: token,
            }
          )
          return
        end

        persist_reply_post!
        clear_resume_state!
      end

      def extract_tool_calls(result_items)
        result_items.filter do |item|
          item.is_a?(DiscourseAi::Completions::ToolCall) && !item.partial?
        end
      end

      def unique_tool_calls(calls)
        seen = {}
        calls.filter do |call|
          key = [call.id.to_s, call.name.to_s, call.parameters.to_json, call.provider_data.to_json]
          !seen[key] && (seen[key] = true)
        end
      end

      def normalize_result(result)
        result = [result] if !result.is_a?(Array)

        result.compact.filter do |item|
          item.is_a?(String) || item.is_a?(DiscourseAi::Completions::ToolCall) ||
            item.is_a?(DiscourseAi::Completions::Thinking)
        end
      end

      def serialize_tool_calls(tool_calls)
        tool_calls.map do |call|
          {
            id: call.id,
            name: call.name,
            parameters: call.parameters,
            provider_data: call.provider_data.presence,
          }.compact
        end
      end

      def apply_tool_results!
        expected = @expected_tool_calls || []
        if expected.blank?
          raise InvalidToolResults, I18n.t("discourse_ai.errors.no_pending_tool_calls")
        end

        supplied =
          @tool_results.index_by do |result|
            result["tool_call_id"].presence || result["id"].presence
          end

        supplied_ids = supplied.keys.compact.map(&:to_s)
        expected_ids = expected.map { |call| call["id"].to_s }

        missing_ids = expected_ids - supplied_ids
        if missing_ids.present?
          raise InvalidToolResults,
                I18n.t("discourse_ai.errors.missing_tool_results", ids: missing_ids.join(", "))
        end

        extra_ids = supplied_ids - expected_ids
        if extra_ids.present?
          raise InvalidToolResults,
                I18n.t("discourse_ai.errors.unexpected_tool_results", ids: extra_ids.join(", "))
        end

        expected.each do |tool_call|
          id = tool_call["id"].to_s
          result = supplied[id]
          has_content = result.key?("content")
          content = result["content"]

          if !has_content || content.nil?
            raise InvalidToolResults,
                  I18n.t("discourse_ai.errors.invalid_tool_result_content", id: id)
          end

          content = content.to_json if !content.is_a?(String)

          @prompt.push(
            type: :tool_call,
            id: id,
            name: tool_call["name"],
            content: { arguments: tool_call["parameters"] || {} }.to_json,
            provider_data: tool_call["provider_data"],
          )
          @prompt.push(type: :tool, id: id, name: tool_call["name"], content: content)
        end
      end

      def persist_state!(tool_calls:)
        next_round_count = @round_count + 1
        if next_round_count > MAX_RESUME_ROUNDS
          raise ProtocolError,
                I18n.t(
                  "discourse_ai.errors.stream_reply_max_resume_rounds_reached",
                  max: MAX_RESUME_ROUNDS,
                )
        end

        token = @resume_token.presence || SecureRandom.hex(32)
        payload = {
          version: 1,
          current_user_id: @current_user&.id,
          persona_id: @persona.id,
          user_id: @user.id,
          topic_id: @topic.id,
          reply_user_id: @reply_user.id,
          llm_model_id: @llm_model_id,
          source_post_number: @source_post_number,
          prompt: {
            messages: @prompt.messages,
            tools: @prompt.tools.map(&:to_h),
            tool_choice: @prompt.tool_choice,
          },
          accumulated_reply: @accumulated_reply,
          expected_tool_calls: serialize_tool_calls(tool_calls),
          temperature: @temperature,
          top_p: @top_p,
          round_count: next_round_count,
        }

        payload_json = payload.to_json
        if payload_json.bytesize > MAX_REDIS_STATE_BYTES
          raise ProtocolError,
                I18n.t(
                  "discourse_ai.errors.stream_reply_state_too_large",
                  max: MAX_REDIS_STATE_BYTES,
                )
        end

        Discourse.redis.setex(self.class.redis_key(token), RESUME_STATE_TTL_SECONDS, payload_json)
        @resume_token = token
        @round_count = next_round_count
        token
      end

      def clear_resume_state!
        return if @resume_token.blank?

        Discourse.redis.del(self.class.redis_key(@resume_token))
      end

      def resume_payload
        return if @resume_token.blank?

        raw = Discourse.redis.getdel(self.class.redis_key(@resume_token))
        return if raw.blank?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      def prompt_from_payload(payload)
        messages =
          deep_symbolize(payload["messages"] || []).map do |message|
            next message if !message.is_a?(Hash)

            message[:type] = message[:type].to_sym if message[:type].is_a?(String)
            message
          end
        tools = payload["tools"] || []

        prompt =
          DiscourseAi::Completions::Prompt.new(
            messages: messages,
            tools:
              tools.map do |tool|
                DiscourseAi::Completions::ToolDefinition.from_hash(tool.deep_symbolize_keys)
              end,
          )

        tool_choice = payload["tool_choice"]
        prompt.tool_choice = tool_choice.to_sym if tool_choice.is_a?(String)

        prompt
      end

      def deep_symbolize(value)
        return value.deep_symbolize_keys if value.is_a?(Hash)
        return value.map { |item| deep_symbolize(item) } if value.is_a?(Array)

        value
      end

      def available_bot_usernames
        @available_bot_usernames ||=
          AiPersona.joins(:user).pluck(:username).concat(available_bot_users.map(&:username))
      end

      def available_bot_users
        @available_bot_users ||=
          User.joins("INNER JOIN llm_models llm ON llm.user_id = users.id").where(active: true)
      end

      def persist_reply_post!
        llm_model = LlmModel.find(@llm_model_id)
        reply_post =
          PostCreator.create!(
            @reply_user,
            topic_id: @topic.id,
            raw: @accumulated_reply,
            skip_validations: true,
            skip_guardian: true,
            custom_fields: {
              DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => llm_model.display_name,
              DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => @llm_model_id,
              DiscourseAi::AiBot::POST_AI_PERSONA_ID_FIELD => @persona.id,
            },
          )

        if @source_post_number == 1 && @topic.private_message?
          persona_class =
            DiscourseAi::Personas::Persona.find_by(id: @persona.id, user: @current_user)
          if persona_class
            bot =
              DiscourseAi::Personas::Bot.as(
                @reply_user,
                persona: persona_class.new,
                model: llm_model,
              )
            begin
              DiscourseAi::AiBot::Playground.new(bot).title_playground(reply_post, @user)
            rescue StandardError => e
              Discourse.warn_exception(e, message: "Discourse AI: Unable to generate stream title")
            end
          end
        end
      end
    end
  end
end
