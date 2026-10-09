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
        agent:,
        llm_model:,
        user:,
        topic:,
        query:,
        custom_instructions:,
        current_user:,
        custom_tools:,
        resume_token:,
        tool_results:
      )
        @agent = agent
        @llm_model = llm_model
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
        @accumulated_tokens = 0
        @accumulated_request_tokens = 0
        @accumulated_response_tokens = 0
      end

      def run(&event_blk)
        raw = Discourse.redis.get(self.class.redis_key(@resume_token)) if resuming?
        payload = parse_resume_payload(raw) if raw.present?
        topic_id = resuming? ? payload&.dig("topic_id") : @topic&.id
        if topic_id
          ReplyLock.synchronize("discourse_ai:reply:topic:#{topic_id}") { run_locked(&event_blk) }
        else
          run_locked(&event_blk)
        end
      end

      private

      def run_locked(&event_blk)
        if resuming?
          load_resume_state!
          apply_tool_results!
        else
          setup_initial_request!
        end
        event_blk.call(
          :context,
          {
            topic_id: @topic.id,
            bot_user_id: @reply_user.id,
            agent_id: @agent.id,
            llm_model_id: @llm_model_id,
          },
        )
        run_single_completion_round!(&event_blk)
      rescue DiscourseAi::Completions::ContextPreparation::Error,
             LlmCreditAllocation::CreditLimitExceeded,
             LlmQuotaUsage::QuotaExceededError => error
        cancelled =
          error.is_a?(DiscourseAi::Completions::ContextPreparation::Error) &&
            error.reason == "cancelled"
        preserve_failure =
          error.is_a?(DiscourseAi::Completions::ContextPreparation::Error) || @round_count > 0 ||
            @accumulated_reply.present?
        resumable_failure = resuming? && @bot && @loaded_resume_payload
        if (@source_post || resumable_failure) && @prompt && !cancelled && preserve_failure
          if resuming? && !@tool_results_applied
            @resume_validation_failed = true
            begin
              apply_tool_results!
            rescue InvalidToolResults
              store_resume_payload!(@resume_token, @loaded_resume_payload)
              raise
            end
          end
          if !@source_post || !@user.guardian.can_see?(@topic)
            payload = @loaded_resume_payload
            # Keep the consumed state if storing accepted results exceeds the size limit.
            store_resume_payload!(@resume_token, payload)
            store_resume_payload!(
              @resume_token,
              payload.merge(
                "failed_tool_results" => @tool_results,
                "work_budget" => @work_budget.snapshot,
                "accumulated_request_tokens" => @accumulated_request_tokens,
                "accumulated_response_tokens" => @accumulated_response_tokens,
                "accumulated_tokens" => @accumulated_tokens,
                "preparation_tokens" => @preparation_tokens,
              ),
            )
            raise
          end
          @accumulated_reply << "\n\n#{error.message}"
          persist_reply_post!(preparation_failed: true)
          clear_resume_state!
        end
        raise
      end

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
          post_params[:target_usernames] = "#{@user.username},#{@agent.user.username}"
          post_params[:topic_opts] = {
            custom_fields: {
              TOPIC_AI_AGENT_ID_FIELD => @agent.id,
              TOPIC_AI_LLM_MODEL_ID_FIELD => @llm_model.id,
            },
          }
        end

        @source_post = PostCreator.create!(@user, post_params)
        @topic = @source_post.topic
        @source_post_number = @source_post.post_number

        agent_class = DiscourseAi::Agents::Agent.find_by(id: @agent.id, user: @current_user)
        raise ProtocolError, I18n.t("discourse_ai.errors.agent_not_found") if agent_class.nil?

        @bot = DiscourseAi::Agents::Bot.as(@agent.user, agent: agent_class.new, model: @llm_model)
        @reply_user = @bot.bot_user
        @llm_model_id = @llm_model.id

        context_llm = @bot.llm
        @history_snapshot =
          DiscourseAi::Completions::HistorySnapshot.post(
            @source_post,
            guardian: @user.guardian,
            bot_usernames: available_bot_usernames,
          )
        context =
          DiscourseAi::Agents::BotContext.new(
            post: @source_post,
            user: @user,
            custom_instructions: @custom_instructions,
            server_owned_tools: false,
            messages:
              DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
                @source_post,
                max_posts: DiscourseAi::Completions::PromptMessagesBuilder::MAX_CONTEXT_MESSAGES,
                history_snapshot: @history_snapshot,
                tokenizer: context_llm.tokenizer,
                include_image_uploads: @bot.agent.class.vision_enabled && @bot.model.native_vision?,
                include_document_uploads: @bot.model.allowed_attachment_types.present?,
                allowed_attachment_types: @bot.model.allowed_attachment_types,
                bot_usernames: available_bot_usernames,
              ),
          )

        @prompt = @bot.agent.craft_prompt(context, llm: context_llm)
        # This endpoint supports caller-owned tool execution. We replace agent tools so every
        # emitted tool call can be completed through the resume protocol.
        @prompt.tools =
          @custom_tools.map do |tool|
            DiscourseAi::Completions::ToolDefinition.from_hash(tool.deep_symbolize_keys)
          end
        @initial_prompt_message_count = @prompt.messages.length
        @protected_user_index = @prompt.messages.rindex { |entry| entry[:type] == :user }
        @temperature = @bot.agent.temperature
        @top_p = @bot.agent.top_p
      end

      def load_resume_state!
        payload = resume_payload
        @loaded_resume_payload = payload
        if payload.blank?
          raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
        end

        if payload["version"] != 3 || payload["history_snapshot"].blank? ||
             payload["work_budget"].blank?
          raise DiscourseAi::Completions::ContextPreparation::Error.new("unsupported_resume_state")
        end

        saved_current_user_id = payload["current_user_id"]
        if saved_current_user_id.blank? || @current_user.blank? ||
             @current_user.id != saved_current_user_id
          raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
        end

        @user = User.find(payload["user_id"])
        @topic = Topic.find(payload["topic_id"])
        saved_reply_user_id = payload["reply_user_id"]
        @llm_model_id = payload["llm_model_id"]
        route =
          ConversationRoute.resolve(
            authorization_user: @current_user,
            modality: :streaming,
            agent_id: payload["agent_id"],
            llm_model_id: @llm_model_id,
            topic: @topic,
            selection_source: :snapshot,
            allow_general_fallback: false,
          )
        if saved_reply_user_id.to_i != route.speaker.id
          raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
        end
        @agent = route.agent_record
        @llm_model = route.model
        @reply_user = route.speaker
        @source_post_number = payload["source_post_number"]
        @temperature = payload["temperature"]
        @top_p = payload["top_p"]
        @accumulated_reply = payload["accumulated_reply"].to_s
        @expected_tool_calls = payload["expected_tool_calls"] || []
        @round_count = payload["round_count"].to_i
        @accumulated_tokens = payload["accumulated_tokens"].to_i
        request_tokens = payload["accumulated_request_tokens"]
        response_tokens = payload["accumulated_response_tokens"]
        if request_tokens.nil? || response_tokens.nil?
          @accumulated_request_tokens = @accumulated_tokens / 2
          @accumulated_response_tokens = @accumulated_tokens - @accumulated_request_tokens
        else
          @accumulated_request_tokens = request_tokens.to_i
          @accumulated_response_tokens = response_tokens.to_i
        end

        @prompt = prompt_from_payload(payload.fetch("prompt"))
        @bot =
          DiscourseAi::Agents::Bot.as(@reply_user, agent: route.agent_class.new, model: @llm_model)
        @source_post = @topic.posts.find_by(post_number: @source_post_number)
        @initial_prompt_message_count = payload["initial_prompt_message_count"].to_i
        @protected_user_index =
          payload["protected_user_index"] ||
            @prompt.messages.rindex { |entry| entry[:type] == :user }
        @preparation_elapsed_seconds = payload["preparation_elapsed_seconds"].to_f
        @preparation_calls = payload["preparation_calls"].to_i
        @preparation_spent_tokens = payload["preparation_spent_tokens"].to_i
        @preparation_tokens = payload["preparation_tokens"].to_i
        work = payload.fetch("work_budget")
        @work_budget =
          DiscourseAi::Completions::TurnWorkBudget.new(
            limit: work.fetch("limit"),
            used: work.fetch("used"),
            event_ids: work.fetch("event_ids"),
            final_answer_claimed: work.fetch("final_answer_claimed"),
          )
        @resume_evidence_scope = payload["evidence_scope"]
        # A failed accepted round is immutable: retries cannot replace evidence under its event IDs.
        @tool_results = payload["failed_tool_results"] if payload["failed_tool_results"]
        if !@source_post || !@topic.topic_allowed_users.exists?(user_id: @user.id)
          raise DiscourseAi::Completions::ContextPreparation::Error.new("history_changed")
        end
        @history_snapshot =
          DiscourseAi::Completions::HistorySnapshot.post(
            @source_post,
            guardian: @user.guardian,
            bot_usernames: available_bot_usernames,
          )
        if payload["history_snapshot"] &&
             !@history_snapshot.validate_checkpoint!(payload["history_snapshot"])
          raise DiscourseAi::Completions::ContextPreparation::Error.new("history_changed")
        end
      rescue ActiveRecord::RecordNotFound, ConversationRoute::Error
        raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
      end

      def run_single_completion_round!
        llm = DiscourseAi::Completions::Llm.proxy(@llm_model_id)
        turn_reply = +""
        streamed_tool_calls = []

        @work_budget ||=
          DiscourseAi::Completions::TurnWorkBudget.new(
            limit: DiscourseAi::Agents::Bot.effective_max_turn_tokens(llm, resolve_token_budget),
          )
        token_usage_tracker =
          DiscourseAi::Completions::TokenUsageTracker.new(
            base_request: @accumulated_request_tokens,
            base_response: @accumulated_response_tokens,
            base_preparation: @preparation_tokens,
          )
        execution_context =
          DiscourseAi::Completions::ExecutionContext.new(
            token_usage_tracker: token_usage_tracker,
            work_budget: @work_budget,
          )
        generate_options = {
          user: @user,
          temperature: @temperature,
          top_p: @top_p,
          execution_context: execution_context,
          feature_name: "bot",
        }

        @preparation =
          DiscourseAi::Completions::ContextPreparation.new(
            llm,
            threshold: resolve_agent_record&.compression_threshold,
            calls: @preparation_calls.to_i,
            spent_tokens: @preparation_spent_tokens.to_i,
            elapsed_seconds: @preparation_elapsed_seconds.to_f,
          )
        # Work admission is independent of history length and cache usage.
        if @work_budget.remaining <= 0
          DiscourseAi::Agents::Bot.inject_token_budget_final_answer_hint(@prompt)
          @prompt.tool_choice = :none

          final_reply = +""
          result =
            generate_with_work_budget!(
              execution_context,
              generate_options,
              final: true,
            ) do |partial|
              if partial.is_a?(String) && !partial.empty?
                final_reply << partial
                yield(:partial, partial)
              end
            end
          @accumulated_reply << final_reply
          @prompt.push_model_response(result)

          persist_reply_post!
          clear_resume_state!
          return
        end

        result =
          generate_with_work_budget!(execution_context, generate_options) do |partial|
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
          result_call_ids = normalized_result.grep(DiscourseAi::Completions::ToolCall).map(&:id)
          response_items =
            normalized_result + tool_calls.reject { |call| result_call_ids.include?(call.id) }
          response_prompt =
            DiscourseAi::Completions::Prompt.new(
              messages: [{ type: :user, content: "Tool response" }],
            )
          response_prompt.push_model_response(response_items)
          @pending_tool_messages = {}
          response_prompt
            .messages
            .drop(1)
            .each do |message|
              if message[:type] == :tool_call
                @pending_tool_messages[message[:id].to_s] = message.slice(
                  :thinking,
                  :thinking_provider_info,
                )
              else
                @prompt.push(**message)
              end
            end
        elsif normalized_result.present?
          @prompt.push_model_response(normalized_result)
        end

        if tool_calls.present?
          if @work_budget.remaining <= 0 ||
               tool_calls.size > DiscourseAi::Agents::Bot::MAX_TOOL_CALLS_PER_COMPLETION
            # Budget exhausted — can't hand tools to client. Push synthetic
            # "not executed" results and give the model one final text-only call.
            tool_calls.each do |call|
              @prompt.push(
                type: :tool_call,
                id: call.id,
                name: call.name,
                content: { arguments: call.parameters }.to_json,
                provider_data: call.provider_data,
                **(@pending_tool_messages[call.id.to_s] || {}),
              )
              content = {
                error: "Not executed — work allowance or tool batch limit reached.",
              }.to_json
              @work_budget.debit(
                @bot.llm.tokenizer.size(content),
                event_id: "client_tool_not_executed:#{@round_count}:#{call.id}",
              )
              @prompt.push(
                type: :tool,
                id: call.id,
                name: call.name,
                content: content,
                provider_data: call.provider_data,
              )
            end

            DiscourseAi::Agents::Bot.inject_token_budget_final_answer_hint(@prompt)
            @prompt.tool_choice = :none

            final_reply = +""
            result =
              generate_with_work_budget!(
                execution_context,
                generate_options,
                final: true,
              ) do |partial|
                if partial.is_a?(String) && !partial.empty?
                  final_reply << partial
                  yield(:partial, partial)
                end
              end
            @accumulated_reply << final_reply
            @prompt.push_model_response(result)

            persist_reply_post!
            clear_resume_state!
            return
          end

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

      def generate_with_work_budget!(execution_context, options, final: false, &block)
        options =
          @work_budget.generation_options(
            options,
            maximum: @bot.model.max_output_tokens.presence || 2500,
            final: final,
            tools: @prompt.tools.present?,
            root: true,
          )
        prepare_prompt!(execution_context, options)
        _, _, provider_output =
          @bot.llm.prompt_capacity(
            @prompt,
            **options.slice(:max_tokens, :thinking_effort, :max_tokens_is_total),
          )
        reservation =
          @work_budget.reserve_generation_output(
            provider_output,
            max_tokens: options[:max_tokens],
            final: final,
            root: true,
          )
        if !reservation
          raise DiscourseAi::Completions::ContextPreparation::Error.new("turn_budget_exhausted")
        end
        @bot.llm.generate(@prompt, **options, work_generation_admitted: true, &block)
      ensure
        @work_budget.release_output(reservation)
        tracker = execution_context.token_usage_tracker
        @accumulated_request_tokens = tracker.request
        @accumulated_response_tokens = tracker.response
        @accumulated_tokens = tracker.total
        @preparation_tokens = tracker.preparation_tokens
      end

      def prepare_prompt!(execution_context, options)
        @history_snapshot.verify!
        result =
          @preparation.prepare!(
            @prompt,
            user: @user,
            execution_context: execution_context,
            protected_user_index: @protected_user_index,
            **options.slice(:max_tokens, :thinking_effort, :response_format, :max_tokens_is_total),
            feature_context: {
              agent_id: @agent.id,
            },
          )
        @protected_user_index = @preparation.protected_user_index if result == :compressed
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
          @work_budget.debit(
            @bot.llm.tokenizer.size(content),
            event_id: "client_tool:#{@round_count}:#{id}",
          )

          provider_data = deep_symbolize(tool_call["provider_data"])
          @prompt.push(
            type: :tool_call,
            id: id,
            name: tool_call["name"],
            content: { arguments: tool_call["parameters"] || {} }.to_json,
            provider_data: provider_data,
            thinking: tool_call["thinking"],
            thinking_provider_info: deep_symbolize(tool_call["thinking_provider_info"]),
          )
          @prompt.push(
            type: :tool,
            id: id,
            name: tool_call["name"],
            content: content,
            provider_data: provider_data,
          )
        end
        @tool_results_applied = true
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
          version: 3,
          work_budget: @work_budget.snapshot,
          initial_prompt_message_count: @initial_prompt_message_count,
          history_snapshot: @history_snapshot.metadata,
          evidence_scope: @history_snapshot.evidence_scope,
          protected_user_index: @protected_user_index,
          preparation_elapsed_seconds: @preparation.elapsed_seconds,
          preparation_calls: @preparation.calls,
          preparation_spent_tokens: @preparation.spent_tokens,
          preparation_tokens: @preparation_tokens,
          current_user_id: @current_user&.id,
          agent_id: @agent.id,
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
          expected_tool_calls:
            serialize_tool_calls(tool_calls).map do |call|
              call.merge(@pending_tool_messages[call[:id].to_s] || {})
            end,
          temperature: @temperature,
          top_p: @top_p,
          round_count: next_round_count,
          accumulated_tokens: @accumulated_tokens,
          accumulated_request_tokens: @accumulated_request_tokens,
          accumulated_response_tokens: @accumulated_response_tokens,
        }

        store_resume_payload!(token, payload)
        @resume_token = token
        @round_count = next_round_count
        token
      end

      def store_resume_payload!(token, payload)
        payload_json = payload.to_json
        if payload_json.bytesize > MAX_REDIS_STATE_BYTES
          raise ProtocolError,
                I18n.t(
                  "discourse_ai.errors.stream_reply_state_too_large",
                  max: MAX_REDIS_STATE_BYTES,
                )
        end
        Discourse.redis.setex(self.class.redis_key(token), RESUME_STATE_TTL_SECONDS, payload_json)
      end

      def clear_resume_state!
        return if @resume_token.blank?

        Discourse.redis.del(self.class.redis_key(@resume_token))
      end

      def resume_payload
        return if @resume_token.blank?

        raw = Discourse.redis.getdel(self.class.redis_key(@resume_token))
        return if raw.blank?

        parse_resume_payload(raw)
      end

      def parse_resume_payload(raw)
        payload = JSON.parse(raw)
        payload if payload.is_a?(Hash)
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
        @available_bot_usernames ||= available_bot_users.pluck(:username)
      end

      def available_bot_users
        @available_bot_users ||=
          User.where(id: DiscourseAi::AiBot::EntryPoint.historical_bot_user_ids)
      end

      def resolve_agent_record
        @_agent_record ||=
          if @agent.is_a?(AiAgent)
            @agent
          else
            AiAgent.find_by(id: @agent.id)
          end
      end

      def resolve_token_budget
        resolve_agent_record&.max_turn_tokens
      end

      def persist_reply_post!(preparation_failed: false)
        @history_snapshot.verify! if !preparation_failed
        has_checkpoint =
          DiscourseAi::Completions::PromptMessagesBuilder.compression_checkpoint_index(
            @prompt.messages,
          )
        raw_context =
          @bot.raw_context_for(
            @prompt,
            start_index:
              (
                if @resume_validation_failed
                  has_checkpoint ? @protected_user_index + 1 : @initial_prompt_message_count
                else
                  (has_checkpoint ? 1 : @initial_prompt_message_count)
                end
              ),
          )
        if preparation_failed
          raw_context =
            DiscourseAi::Completions::PromptMessagesBuilder.without_checkpoint(raw_context)
          scope = @resume_evidence_scope || @history_snapshot&.evidence_scope
          raw_context.each { |entry| entry[7] = scope }
        else
          @history_snapshot.stamp!(raw_context)
        end
        reply_post =
          PostCreator.create!(
            @reply_user,
            topic_id: @topic.id,
            raw: @accumulated_reply,
            skip_validations: true,
            skip_guardian: true,
            custom_fields: {
              DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => @llm_model.display_name,
              DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => @llm_model_id,
              DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => @agent.id,
              DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD => @current_user.id,
            },
          )

        if raw_context.present?
          PostCustomPrompt.create!(post_id: reply_post.id, custom_prompt: raw_context)
        end

        if !preparation_failed && @source_post_number == 1 && @topic.private_message?
          agent_class = DiscourseAi::Agents::Agent.find_by(id: @agent.id, user: @current_user)
          if agent_class
            bot =
              DiscourseAi::Agents::Bot.as(@reply_user, agent: agent_class.new, model: @llm_model)
            DiscourseAi::AiBot::Playground.new(bot).title_playground(reply_post, @user)
          end
        end
      end
    end
  end
end
