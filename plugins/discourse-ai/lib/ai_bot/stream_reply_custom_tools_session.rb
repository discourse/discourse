# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class StreamReplyCustomToolsSession
      RESUME_STATE_PREFIX = "discourse_ai:stream_reply:custom_tools:"
      RESUME_STATE_TTL_SECONDS = 15.minutes.to_i
      MAX_RESUME_ROUNDS = 10
      # Clients must be able to submit every result in a single resume request.
      MAX_TOOL_RESULTS = [20, DiscourseAi::Agents::Bot::MAX_TOOL_CALLS_PER_COMPLETION].min
      MAX_REDIS_STATE_BYTES = 500 * 1024

      UPDATE_RESUME_STATE = <<~LUA
        if redis.call("GET", KEYS[1]) ~= ARGV[1] then
          return 0
        end
        if ARGV[2] then
          return redis.call("SET", KEYS[1], ARGV[2], "XX", "KEEPTTL") and 1 or 0
        end
        return redis.call("DEL", KEYS[1])
      LUA
      private_constant :UPDATE_RESUME_STATE

      class ProtocolError < StandardError
      end

      class ResumeTokenNotFound < ProtocolError
      end

      class InvalidToolResults < ProtocolError
      end

      def self.resume_state_exists?(resume_token)
        return false if resume_token.blank?

        # Pending state is a JSON object; in-flight claims are not resumable.
        Discourse.redis.getrange(redis_key(resume_token), 0, 0) == "{"
      end

      def self.redis_key(resume_token)
        "#{RESUME_STATE_PREFIX}#{resume_token}"
      end

      def self.tool_result_id(result)
        call_id = result["tool_call_id"].presence&.to_s
        alias_id = result["id"].presence&.to_s
        return if call_id && alias_id && call_id != alias_id

        call_id || alias_id
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
        @tool_results = Array(tool_results)
        @accumulated_reply = +""
        @round_count = 0
        @accumulated_tokens = 0
        @accumulated_request_tokens = 0
        @accumulated_response_tokens = 0
      end

      def run(&event_blk)
        if resuming?
          key = self.class.redis_key(@resume_token)
          raw = Discourse.redis.get(key)
          payload = parse_resume_payload(raw) if raw.present?
          topic_id = payload&.dig("topic_id")
          if topic_id.blank? || @current_user.nil? || @current_user.id != payload["current_user_id"]
            raise_invalid_resume_token!
          end
        else
          topic_id = @topic&.id
        end

        if topic_id
          ReplyLock.synchronize("discourse_ai:reply:topic:#{topic_id}") do
            run_locked(raw, payload, &event_blk)
          end
        else
          run_locked(&event_blk)
        end
      end

      private

      def run_locked(raw = nil, payload = nil, &event_blk)
        if resuming?
          resume_round!(raw, payload)
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
        resumable_failure = resuming? && @resume_claim
        if (@source_post || resumable_failure) && @prompt && !cancelled && preserve_failure &&
             (!resuming? || resumable_failure)
          if !@source_post || !@user.guardian.can_see?(@topic)
            preserve_failed_resume! if resumable_failure
            raise
          end
          @accumulated_reply << "\n\n#{error.message}"
          persist_reply_post!(preparation_failed: true)
        end
        raise
      ensure
        update_resume_state(@resume_claim) if @resume_claim
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
        @protected_user_index = @prompt.user_request_index
        @temperature = @bot.agent.temperature
        @top_p = @bot.agent.top_p
      end

      def resume_round!(raw, payload)
        if Discourse.redis.get(self.class.redis_key(@resume_token)) != raw
          raise_invalid_resume_token!
        end

        load_resume_state!(payload)
        result_costs = preflight_tool_results!
        history_error = resume_history_error(payload)

        # The topic lock serializes normal replies, but expiry or another claimant can
        # still invalidate the exact state we preflighted. Keep its deadline on the claim.
        claim = "claimed:#{SecureRandom.hex(32)}"
        raise_invalid_resume_token! if !update_resume_state(raw, claim)
        @resume_claim = claim
        @loaded_resume_payload = payload
        @original_resume_state = raw

        apply_tool_results!(result_costs)
        if history_error
          @resume_validation_failed = true
          raise history_error
        end
      rescue InvalidToolResults
        if Discourse.redis.get(self.class.redis_key(@resume_token)) != raw
          raise_invalid_resume_token!
        end
        raise
      end

      def load_resume_state!(payload)
        if @current_user.nil? || @current_user.id != payload["current_user_id"]
          raise_invalid_resume_token!
        end

        if payload["version"] != 3 || payload["history_snapshot"].blank? ||
             payload["work_budget"].blank?
          raise DiscourseAi::Completions::ContextPreparation::Error.new("unsupported_resume_state")
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
        raise_invalid_resume_token! if saved_reply_user_id.to_i != route.speaker.id
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
        @initial_prompt_message_count =
          @prompt.normalized_message_offset(payload["initial_prompt_message_count"].to_i)
        @protected_user_index =
          @prompt.normalized_user_request_index(payload["protected_user_index"])
        # Resume rounds provide a lower bound when a payload lacks an execution count.
        @completion_count = payload.fetch("completion_count", @round_count).to_i
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
      rescue ActiveRecord::RecordNotFound, ConversationRoute::Error
        raise_invalid_resume_token!
      end

      def resume_history_error(payload)
        if !@source_post || !@topic.topic_allowed_users.exists?(user_id: @user.id)
          raise DiscourseAi::Completions::ContextPreparation::Error.new("history_changed")
        end
        @history_snapshot =
          DiscourseAi::Completions::HistorySnapshot.post(
            @source_post,
            guardian: @user.guardian,
            bot_usernames: available_bot_usernames,
          )
        if !@history_snapshot.validate_checkpoint!(payload["history_snapshot"])
          raise DiscourseAi::Completions::ContextPreparation::Error.new("history_changed")
        end
        nil
      rescue DiscourseAi::Completions::ContextPreparation::Error => error
        # A valid submitted batch remains evidence even if history prevents generation.
        error
      end

      def run_single_completion_round!
        llm = DiscourseAi::Completions::Llm.proxy(@llm_model_id)
        turn_reply = +""
        streamed_tool_calls = []

        @work_budget ||=
          DiscourseAi::Completions::TurnWorkBudget.new(
            limit: DiscourseAi::Agents::Bot.effective_max_turn_tokens(resolve_token_budget),
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
        @execution_state =
          DiscourseAi::Agents::SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: @work_budget.limit,
            completion_count: @completion_count.to_i,
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
          if @work_budget.remaining <= 0 || tool_calls.size > MAX_TOOL_RESULTS
            # Don't hand out a batch the client cannot submit. Explain the skipped calls
            # to the model before its final text-only completion.
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
      end

      def generate_with_work_budget!(execution_context, options, final: false, &block)
        if !final && !@execution_state.completion_available?
          request_completion_limit_final_answer!
          final = true
        end

        generation_options = work_generation_options(options, final: final)
        # Maintenance can use the last ordinary slot; reserve the reply only after it fits.
        prepare_prompt!(execution_context, generation_options)
        if !final && !@execution_state.reserve_completion
          request_completion_limit_final_answer!
          final = true
          generation_options = work_generation_options(options, final: final)
          size, capacity =
            @bot.llm.prompt_capacity(
              @prompt,
              **generation_options.slice(
                :max_tokens,
                :thinking_effort,
                :response_format,
                :max_tokens_is_total,
              ),
            )
          # Recheck the final hint/output allowance without another soft-threshold compression.
          prepare_prompt!(execution_context, generation_options) if capacity <= 0 || size > capacity
        end
        if final && !@execution_state.reserve_root_final_completion
          raise DiscourseAi::Completions::ContextPreparation::Error.new("completion_limit")
        end

        _, _, provider_output =
          @bot.llm.prompt_capacity(
            @prompt,
            **generation_options.slice(
              :max_tokens,
              :thinking_effort,
              :response_format,
              :max_tokens_is_total,
            ),
          )
        reservation =
          @work_budget.reserve_generation_output(
            provider_output,
            max_tokens: generation_options[:max_tokens],
            final: final,
            root: true,
          )
        if !reservation
          raise DiscourseAi::Completions::ContextPreparation::Error.new("turn_budget_exhausted")
        end
        @bot.llm.generate(@prompt, **generation_options, work_generation_admitted: true, &block)
      ensure
        @work_budget.release_output(reservation)
        @completion_count = @execution_state.completion_count
        tracker = execution_context.token_usage_tracker
        @accumulated_request_tokens = tracker.request
        @accumulated_response_tokens = tracker.response
        @accumulated_tokens = tracker.total
        @preparation_tokens = tracker.preparation_tokens
      end

      def work_generation_options(options, final:)
        @work_budget.generation_options(
          options.merge(
            thinking_allowance:
              DiscourseAi::Completions::ThinkingConfig.response_allowance_for(
                llm_model: @bot.model,
                effort: options[:thinking_effort],
              ),
          ),
          maximum: @bot.model.max_output_tokens.presence,
          final: final,
          tools: @prompt.tools.present?,
          root: true,
        )
      end

      def request_completion_limit_final_answer!
        @prompt.push(
          type: :user,
          content: DiscourseAi::Agents::Bot::COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        )
        @prompt.tool_choice = :none
      end

      def prepare_prompt!(execution_context, options)
        @history_snapshot.verify!
        result =
          @preparation.prepare!(
            @prompt,
            user: @user,
            execution_context: execution_context,
            subagent_execution_state: @execution_state,
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

      def validate_tool_results!
        if @expected_tool_calls.blank?
          raise InvalidToolResults, I18n.t("discourse_ai.errors.no_pending_tool_calls")
        end

        expected_ids = @expected_tool_calls.map { |call| call["id"].to_s }
        if expected_ids.any?(&:blank?) || expected_ids.uniq.size != expected_ids.size
          raise_invalid_resume_token!
        end

        supplied = {}
        duplicate_ids = Set.new
        @tool_results.each do |result|
          if !result.is_a?(Hash)
            raise InvalidToolResults, I18n.t("discourse_ai.errors.expected_object")
          end

          result = result.stringify_keys
          id = self.class.tool_result_id(result)
          if id.nil?
            raise InvalidToolResults,
                  I18n.t("discourse_ai.errors.invalid_tool_results", details: "tool_call_id")
          end
          duplicate_ids.add(id) if supplied.key?(id)
          supplied[id] = result
        end
        if duplicate_ids.present?
          raise InvalidToolResults,
                I18n.t(
                  "discourse_ai.errors.duplicate_tool_results",
                  ids: duplicate_ids.to_a.join(", "),
                )
        end

        missing_ids = expected_ids - supplied.keys
        if missing_ids.present?
          raise InvalidToolResults,
                I18n.t("discourse_ai.errors.missing_tool_results", ids: missing_ids.join(", "))
        end

        extra_ids = supplied.keys - expected_ids
        if extra_ids.present?
          raise InvalidToolResults,
                I18n.t("discourse_ai.errors.unexpected_tool_results", ids: extra_ids.join(", "))
        end

        @expected_tool_calls.map do |tool_call|
          id = tool_call["id"].to_s
          content = supplied.fetch(id)["content"]
          if content.nil?
            raise InvalidToolResults,
                  I18n.t("discourse_ai.errors.invalid_tool_result_content", id: id)
          end
          [tool_call, content.is_a?(String) ? content : content.to_json]
        rescue JSON::GeneratorError
          raise InvalidToolResults,
                I18n.t("discourse_ai.errors.invalid_tool_result_content", id: id)
        end
      end

      def preflight_tool_results!
        results = validate_tool_results!
        tokenizer = @bot.llm.tokenizer
        results.map { |tool_call, content| [tool_call, content, tokenizer.size(content)] }
      end

      def apply_tool_results!(results)
        results.each do |tool_call, content, size|
          id = tool_call["id"].to_s
          @work_budget.debit(size, event_id: "client_tool:#{@round_count}:#{id}")

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

        # A delayed delivery must not match a later round even if the model reuses its call IDs.
        token = SecureRandom.hex(32)
        payload = {
          version: 3,
          work_budget: @work_budget.snapshot,
          initial_prompt_message_count: @initial_prompt_message_count,
          history_snapshot: @history_snapshot.metadata,
          evidence_scope: @history_snapshot.evidence_scope,
          protected_user_index: @protected_user_index,
          completion_count: @completion_count,
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

        key = self.class.redis_key(token)
        if !Discourse.redis.set(
             key,
             serialize_resume_payload(payload),
             ex: RESUME_STATE_TTL_SECONDS,
             nx: true,
           )
          raise_invalid_resume_token!
        end
        @round_count = next_round_count
        token
      end

      def preserve_failed_resume!
        payload =
          @loaded_resume_payload.merge(
            "failed_tool_results" => @tool_results,
            "work_budget" => @work_budget.snapshot,
            "accumulated_request_tokens" => @accumulated_request_tokens,
            "accumulated_response_tokens" => @accumulated_response_tokens,
            "accumulated_tokens" => @accumulated_tokens,
            "preparation_tokens" => @preparation_tokens,
            "completion_count" => @completion_count,
          )
        update_resume_state(@resume_claim, serialize_resume_payload(payload))
      rescue ProtocolError
        # The original state is a safe size-limit fallback only before any model work
        # and before the batch has been locked in as accepted evidence.
        previous_count = @loaded_resume_payload.fetch("completion_count", @round_count).to_i
        if @completion_count == previous_count
          update_resume_state(@resume_claim, @original_resume_state)
        end
        raise
      end

      def serialize_resume_payload(payload)
        payload_json = payload.to_json
        if payload_json.bytesize > MAX_REDIS_STATE_BYTES
          raise ProtocolError,
                I18n.t(
                  "discourse_ai.errors.stream_reply_state_too_large",
                  max: MAX_REDIS_STATE_BYTES,
                )
        end
        payload_json
      end

      def update_resume_state(expected, replacement = nil)
        redis = Discourse.redis
        key = redis.namespace_key(self.class.redis_key(@resume_token))
        argv = [expected]
        argv << replacement if replacement
        redis.eval(UPDATE_RESUME_STATE, keys: [key], argv: argv) == 1
      end

      def raise_invalid_resume_token!
        raise ResumeTokenNotFound, I18n.t("discourse_ai.errors.invalid_stream_resume_token")
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
