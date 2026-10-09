# frozen_string_literal: true

module DiscourseAi
  module Agents
    class Bot
      BOT_NOT_FOUND = Class.new(StandardError)

      DEFAULT_MAX_TURN_TOKENS = 500_000
      MAX_DISCOVERED_IMAGE_REFERENCES = 20
      MAX_TOOL_CALLS_PER_COMPLETION = 50
      MAX_FINAL_ANSWER_TOKENS = DiscourseAi::Completions::TurnWorkBudget::MAX_FINAL_ANSWER_TOKENS
      COMPRESSED_CONTEXT_PREFIX =
        DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_PREFIX
      COMPRESSED_CONTEXT_SUFFIX =
        DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_SUFFIX
      COMPRESSED_CONTEXT_ACK =
        DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK

      SUBAGENT_FEATURE_CONTEXT_KEYS = %w[
        subagent_parent_agent_id
        subagent_agent_id
        subagent_depth
      ].freeze

      TOKEN_BUDGET_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The turn work allowance has been reached — no further tool calls are available.]
        Provide your final response now using the information already gathered.
        Do not describe additional tool calls or future work as though you will perform them.
        If the task is not fully complete, clearly state what was accomplished
        and what still needs to be done so the user can continue in a follow-up message.
      TEXT
      TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The tool invocation limit has been reached — no further tool calls are available.]
        Provide your final response now using the information already gathered.
        If the evidence is insufficient, say so instead of attempting another tool call.
      TEXT
      COMPLETION_LIMIT_FINAL_ANSWER_HINT = <<~TEXT.strip
        [The shared completion safety limit has been reached — no further tool calls are available.]
        Provide one final response using the information already gathered.
      TEXT
      LEGACY_BUDGET_EXHAUSTED_HINT = <<~TEXT.strip
        [Turn budget exhausted — you cannot call any more tools.]
        Provide your final response using the information already gathered.
        If the task is not fully complete, clearly state what was accomplished
        and what still needs to be done so the user can continue in a follow-up message.
      TEXT
      BUDGET_EXHAUSTED_HINT = TOKEN_BUDGET_FINAL_ANSWER_HINT
      TRANSIENT_TOKEN_BUDGET_HINTS = [
        TOKEN_BUDGET_FINAL_ANSWER_HINT,
        TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT,
        COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        LEGACY_BUDGET_EXHAUSTED_HINT,
      ].freeze

      def self.inject_tool_invocation_budget_final_answer_hint(prompt)
        prompt.push(type: :user, content: TOOL_INVOCATION_BUDGET_FINAL_ANSWER_HINT)
      end

      def self.inject_token_budget_final_answer_hint(prompt)
        prompt.push(type: :user, content: TOKEN_BUDGET_FINAL_ANSWER_HINT)
      end

      def self.inject_budget_exhausted_hint(prompt)
        inject_token_budget_final_answer_hint(prompt)
      end

      def self.effective_max_turn_tokens(requested = nil)
        requested.to_i > 0 ? requested.to_i : DEFAULT_MAX_TURN_TOKENS
      end

      def self.as(bot_user, agent: DiscourseAi::Agents::General.new, model: nil)
        new(bot_user, agent, model)
      end

      def self.json_schema_properties(response_format)
        response_format
          .to_a
          .reduce({}) do |memo, format|
            next memo if !format.is_a?(Hash) || format["key"].blank?

            type_desc = { type: format["type"] }

            if format["type"] == "array"
              type_desc[:items] = if format["items"].is_a?(Hash)
                format["items"].deep_symbolize_keys
              else
                { type: format["array_type"] || "string" }
              end
              max_items = format["max_items"]
              type_desc[:maxItems] = max_items if max_items.is_a?(Integer) && max_items >= 0
            end

            memo[format["key"].to_sym] = type_desc
            memo
          end
      end

      def self.build_json_schema(response_format)
        properties = json_schema_properties(response_format)

        {
          type: "json_schema",
          json_schema: {
            name: "reply",
            schema: {
              type: "object",
              properties: properties,
              required: properties.keys.map(&:to_s),
              additionalProperties: false,
            },
            strict: true,
          },
        }
      end

      def initialize(bot_user, agent, model = nil)
        @bot_user = bot_user
        @agent = agent
        @model =
          model || self.class.guess_model(bot_user) ||
            LlmModel.find(@agent.class.default_llm_id || SiteSetting.ai_default_llm_model)
      end

      attr_reader :bot_user, :model
      attr_accessor :agent

      def llm
        DiscourseAi::Completions::Llm.proxy(model)
      end

      def force_tool_if_needed(prompt, context, force: true, ignore_forced_tool_count: false)
        return if prompt.tool_choice == :none

        context.chosen_tools ||= []
        if !force
          prompt.tool_choice = nil
          return
        end

        forced_tools = agent.force_tool_use.map { |tool| tool.name }
        force_tool = forced_tools.find { |name| !context.chosen_tools.include?(name) }

        if force_tool && agent.forced_tool_count > 0 && !ignore_forced_tool_count
          user_turns =
            context.user_turn_count ||
              prompt.messages.count do |message|
                message[:type] == :user && !transient_prompt_hint?(message)
              end
          force_tool = false if user_turns > agent.forced_tool_count
        end

        if force_tool
          context.chosen_tools << force_tool
          prompt.tool_choice = force_tool
        else
          prompt.tool_choice = nil
        end
      end

      def reply(context, llm_args: {}, execution_context: nil, &update_blk)
        unless context.is_a?(BotContext)
          raise ArgumentError, "context must be an instance of BotContext"
        end
        update_blk ||= proc {}
        context.partial_raw_context = nil

        context.cancel_manager ||= DiscourseAi::Completions::CancelManager.new
        current_llm = llm
        token_budget =
          self.class.effective_max_turn_tokens(
            context.turn_token_budget.presence || agent.class.max_turn_tokens.presence,
          )
        execution_context ||=
          context.execution_context || DiscourseAi::Completions::ExecutionContext.new
        if context.subagent_depth.to_i.zero? && execution_context.root_reply_completed
          execution_context = execution_context.for_new_turn
          context.subagent_execution_state = nil
        end
        execution_context.token_usage_tracker ||= DiscourseAi::Completions::TokenUsageTracker.new
        context.execution_context = execution_context
        context.subagent_execution_state ||=
          SubagentExecutionState.new(
            execution_context: execution_context,
            root_token_budget: token_budget,
          )
        context.current_agent_id ||= agent.id
        work_budget = execution_context.work_budget

        context.user_turn_count ||=
          context.messages.count do |message|
            message[:type] == :user && !transient_prompt_hint?(message) &&
              !DiscourseAi::Completions::PromptMessagesBuilder.message_text(message).start_with?(
                COMPRESSED_CONTEXT_PREFIX,
              )
          end
        prompt = agent.craft_prompt(context, llm: current_llm)
        preparation =
          DiscourseAi::Completions::ContextPreparation.new(
            current_llm,
            threshold: agent.class.compression_threshold,
          )
        protected_user_message =
          if context.protected_message_count
            prompt.messages[-context.protected_message_count]
          else
            prompt.messages.reverse.find do |message|
              message[:type] == :user && !transient_prompt_hint?(message)
            end
          end
        defer_forced_tool =
          agent.defer_forced_tool_for_vision? &&
            context.runtime_tools&.include?(Tools::ViewImage) &&
            context.authorized_image_upload_ids.present?
        fallback_force_required = false

        ongoing_chain = true
        raw_context = []

        user = context.user

        llm_kwargs = llm_args.dup
        llm_kwargs[:user] = user
        context_feature_attribution =
          context.feature_context.to_h.deep_stringify_keys.slice(*SUBAGENT_FEATURE_CONTEXT_KEYS)
        llm_kwargs[:feature_context] = llm_args[:feature_context].to_h.deep_stringify_keys.merge(
          context_feature_attribution,
        )
        llm_kwargs[:temperature] = agent.temperature if agent.temperature
        llm_kwargs[:top_p] = agent.top_p if agent.top_p
        llm_kwargs[:thinking_effort] = agent.thinking_effort if agent.thinking_effort.present?

        if !context.bypass_response_format && agent.response_format.present?
          llm_kwargs[:response_format] = self.class.build_json_schema(agent.response_format)
        end

        needs_newlines = false

        llm_kwargs[:execution_context] = execution_context
        enable_gemini_thought_summaries!(llm_kwargs, current_llm, context)

        final_answer_requested = false
        tool_invocation_budget_exhausted = false

        while ongoing_chain
          if final_answer_requested
            break # already ran the final text-only generate
          end
          break if context.cancel_manager.cancelled?

          if tool_invocation_budget_exhausted
            self.class.inject_tool_invocation_budget_final_answer_hint(prompt)
            prompt.tool_choice = :none
            final_answer_requested = true
            tool_invocation_budget_exhausted = false
          end

          budget_exhausted = work_budget.remaining <= 0
          if budget_exhausted && context.subagent_depth.to_i > 0
            raise DiscourseAi::Completions::ContextPreparation::Error.new("turn_budget_exhausted")
          end
          if !final_answer_requested && budget_exhausted
            self.class.inject_token_budget_final_answer_hint(prompt)
            prompt.tool_choice = :none
            final_answer_requested = true
          end

          tool_found = false
          force_tool_if_needed(
            prompt,
            context,
            force: !defer_forced_tool || fallback_force_required,
            ignore_forced_tool_count: defer_forced_tool && fallback_force_required,
          )

          tool_halted = false

          allow_partial_tool_calls = agent.allow_partial_tool_calls?
          existing_tools = Set.new
          current_thinking = []
          thinking_placeholder = nil

          completion_reserved =
            if final_answer_requested && context.subagent_depth.to_i.zero?
              context.subagent_execution_state.reserve_root_final_completion
            else
              context.subagent_execution_state.reserve_completion
            end

          unless completion_reserved
            if final_answer_requested
              context.completion_limit_reached = true
              break
            end

            prompt.push(type: :user, content: COMPLETION_LIMIT_FINAL_ANSWER_HINT)
            prompt.tool_choice = :none
            final_answer_requested = true

            if context.subagent_depth.to_i.zero?
              break if !context.subagent_execution_state.reserve_root_final_completion
            else
              context.completion_limit_reached = true
              break
            end
          end

          root_generation = context.subagent_depth.to_i.zero?
          generation_options =
            work_budget.generation_options(
              llm_kwargs,
              maximum: llm_kwargs[:max_tokens] || model.max_output_tokens.presence || 2500,
              final: final_answer_requested,
              tools: prompt.tools.present? && prompt.tool_choice != :none,
              root: root_generation,
            )
          capacity_options =
            generation_options.slice(
              :max_tokens,
              :thinking_effort,
              :response_format,
              :max_tokens_is_total,
            )
          compression_result =
            preparation.prepare!(
              prompt,
              user: user,
              execution_context: execution_context,
              cancel_manager: context.cancel_manager,
              subagent_execution_state: context.subagent_execution_state,
              feature_context: llm_kwargs[:feature_context],
              protected_user_index: prompt.messages.index(protected_user_message),
              **capacity_options,
            )
          if compression_result == :compressed
            protected_user_message = prompt.messages[preparation.protected_user_index]
            raw_context.replace(messages_to_raw_context(prompt.messages.drop(1)))
          end
          break if context.cancel_manager.cancelled?
          context.history_snapshot&.verify!
          _, _, provider_output = current_llm.prompt_capacity(prompt, **capacity_options)
          reservation =
            work_budget.reserve_generation_output(
              provider_output,
              max_tokens: generation_options[:max_tokens],
              final: final_answer_requested,
              root: root_generation,
            )
          break if !reservation
          tool_batch_count = 0

          begin
            result =
              current_llm.generate(
                prompt,
                feature_name: context.feature_name,
                partial_tool_calls: allow_partial_tool_calls,
                output_thinking: true,
                work_generation_admitted: true,
                cancel_manager: context.cancel_manager,
                **generation_options,
              ) do |partial|
                tool =
                  agent.find_tool(
                    partial,
                    bot_user: user,
                    llm: current_llm,
                    context: context,
                    existing_tools: existing_tools,
                  )
                if tool.present?
                  existing_tools << tool
                  tool_call = partial
                  if tool_call.partial?
                    if tool.class.allow_partial_tool_calls? && !final_answer_requested &&
                         tool_batch_count < MAX_TOOL_CALLS_PER_COMPLETION
                      tool.partial_invoke
                      update_blk.call("", tool.custom_raw, :partial_tool)
                    end
                    next
                  end

                  tool_found = true
                  fallback_force_required = true if defer_forced_tool &&
                    tool.name == Tools::ViewImage.name
                  # a bit hacky, but extra newlines do no harm
                  if needs_newlines
                    update_blk.call("\n\n")
                    needs_newlines = false
                  end

                  tool_batch_count += 1
                  tool_result =
                    process_tool(
                      execute:
                        !final_answer_requested &&
                          tool_batch_count <= MAX_TOOL_CALLS_PER_COMPLETION,
                      tool: tool,
                      raw_context: raw_context,
                      current_llm: current_llm,
                      update_blk: update_blk,
                      prompt: prompt,
                      context: context,
                      current_thinking: current_thinking,
                    )

                  tool_invocation_budget_exhausted ||=
                    tool_batch_count >= MAX_TOOL_CALLS_PER_COMPLETION ||
                      spawn_agent_budget_exhausted?(tool, context) ||
                      tool_invocation_budget_exhausted?(context)

                  chain_next_response =
                    tool.chain_next_response? &&
                      !(
                        agent.stop_chain_on_pending_approval? && tool_result.is_a?(Hash) &&
                          tool_result[:status] == "pending_approval"
                      )
                  ongoing_chain &&= chain_next_response

                  tool_halted = true if !chain_next_response
                else
                  next if tool_halted
                  needs_newlines = true
                  if partial.is_a?(DiscourseAi::Completions::ToolCall)
                    Rails.logger.warn("DiscourseAi: Tool not found: #{partial.name}")
                  else
                    if partial.is_a?(DiscourseAi::Completions::Thinking)
                      thinking = partial

                      if thinking.partial? && thinking.message.present? &&
                           !context.skip_show_thinking
                        thinking_placeholder ||= +""
                        thinking_placeholder << thinking.message
                        update_blk.call("", thinking_placeholder, :thinking)
                      end

                      if !thinking.partial?
                        raw_context << thinking
                        current_thinking << thinking
                        thinking_placeholder = nil
                        if thinking.message.present?
                          update_blk.call(thinking.message, nil, :thinking)
                        end
                      end
                    else
                      if partial.is_a?(DiscourseAi::Completions::StructuredOutput)
                        update_blk.call(partial, nil, :structured_output)
                      else
                        update_blk.call(partial)
                      end
                    end
                  end
                end
              end
          ensure
            work_budget.release_output(reservation)
          end

          if !tool_found
            if defer_forced_tool && !fallback_force_required && !final_answer_requested
              fallback_force_required = true
              prompt.tool_choice = nil
              ongoing_chain = true
            else
              ongoing_chain = false
              # we must strip out thinking and other types of blocks
              text = DiscourseAi::Completions::Llm.text_from_response(result)
              raw_context << [text, bot_user&.username]
            end
          end
        end

        result = embed_thinking(raw_context)
        context.history_snapshot&.stamp!(result)
        result
      rescue => error
        raise if !context.is_a?(BotContext)
        context.partial_raw_context = embed_thinking(raw_context || [])
        if context.history_snapshot
          context.partial_raw_context =
            DiscourseAi::Completions::PromptMessagesBuilder.without_checkpoint(
              context.partial_raw_context,
            )
          context.partial_raw_context.each do |entry|
            entry[7] = context.history_snapshot.evidence_scope
          end
        end
        error.raw_context = context.partial_raw_context if error.is_a?(
          DiscourseAi::Completions::ContextPreparation::Error,
        )
        raise
      ensure
        execution_context.root_reply_completed = true if execution_context &&
          context.is_a?(BotContext) && context.subagent_depth.to_i.zero?
      end

      def raw_context_for(prompt, start_index: 1)
        messages_to_raw_context(prompt.messages.drop(start_index))
      end

      def returns_json?
        agent.response_format.present?
      end

      private

      def spawn_agent_budget_exhausted?(tool, context)
        tool.is_a?(Tools::SpawnAgent) && !context.subagent_execution_state.spawn_available?
      end

      def tool_invocation_budget_exhausted?(context)
        runtime_tools = context.runtime_tools.presence || agent.available_tools
        return false if runtime_tools.empty?

        runtime_tools.all? do |tool_class|
          if tool_class <= Tools::SpawnAgent
            !context.subagent_execution_state.spawn_available?
          else
            limit = agent.options[tool_class].to_h.with_indifferent_access[:max_invocations].to_i
            context.tool_invocation_limit_reached?(tool_class.name, limit: limit)
          end
        end
      end

      def enable_gemini_thought_summaries!(llm_kwargs, current_llm, context)
        return if !%w[google gemini_interactions].include?(current_llm.llm_model.provider)
        return if context.skip_show_thinking != false

        extra_model_params = (llm_kwargs[:extra_model_params] || {}).dup
        extra_model_params[:include_thought_summaries] = true
        llm_kwargs[:extra_model_params] = extra_model_params
      end

      def embed_thinking(raw_context)
        embedded_thinking = []
        thinking_bundle = nil

        raw_context.each do |context|
          if context.is_a?(DiscourseAi::Completions::Thinking)
            thinking_bundle ||= { message: nil, provider_info: {} }
            thinking_bundle[:message] = merge_thinking_message(
              thinking_bundle[:message],
              context.message,
            )
            thinking_bundle[
              :provider_info
            ] = DiscourseAi::Completions::Thinking.merge_provider_info(
              thinking_bundle[:provider_info],
              context.provider_info,
            )
            next
          end

          if thinking_bundle
            context = context.dup
            context[4] = {
              "message" => thinking_bundle[:message],
              "provider_info" =>
                DiscourseAi::Completions::Thinking.deep_stringify_keys(
                  thinking_bundle[:provider_info],
                ),
            }.compact
            thinking_bundle = nil
          end

          embedded_thinking << context
        end

        embedded_thinking
      end

      def merge_thinking_message(existing, incoming)
        return existing if incoming.blank?
        return incoming if existing.blank?

        "#{existing}\n\n#{incoming}"
      end

      def tool_requires_approval?(tool)
        return true if tool.class.mandatory_approval?

        tool.class.requires_approval? && @agent.class.require_approval
      end

      def enqueue_tool_for_approval(tool, context, &update_blk)
        tool_action =
          AiToolAction.create!(
            tool_name: tool.name,
            tool_parameters: tool.parameters,
            ai_agent_id: @agent.id,
            bot_user_id: @bot_user.id,
            post_id: context.post_id,
          )

        reviewable =
          ReviewableAiToolAction.needs_review!(
            target: tool_action,
            created_by: @bot_user,
            reviewable_by_moderator: true,
            payload: {
              agent_name: @agent.class.name,
              reason: tool.parameters[:reason],
              llm_model_id: @model&.id,
              chat_message_id: context.message_id,
              context_post_ids: context.context_post_ids,
            },
          )

        reviewable.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          force_review: true,
        )

        if context.channel_id.present?
          # In chat the reply is rendered as interactive "blocks"; the chat
          # reply handler turns this into an Approve/Reject block message.
          update_blk.call(
            {
              reviewable_id: reviewable.id,
              summary: tool.approval_title,
              changes: tool.approval_changes,
              details: tool.approval_details,
              description_label: tool.approval_description_label,
              show_description: tool.approval_show_description?,
              question: tool.approval_question,
              parameters: tool.approval_parameters,
            },
            nil,
            :chat_approval,
          )
        else
          # :custom_raw lands in the persisted reply as visible content —
          # a :thinking emission would be dropped (or collapsed into the
          # thinking details block) depending on the agent's show_thinking.
          # This is an empty mount point (keyed by the reviewable id); the client
          # decorator renders the AiToolApproval card component into it, so the
          # `.ai-tool-approval` element exists only once, on the component itself.
          approval_card = "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>"

          approval_notice =
            ERB::Util.html_escape(I18n.t("discourse_ai.ai_bot.tool_pending_approval"))
          approval_content = "#{approval_notice}\n\n#{approval_card}\n\n"
          update_blk.call(approval_content, nil, :custom_raw)
        end

        { status: "pending_approval", message: I18n.t("discourse_ai.ai_bot.tool_pending_approval") }
      end

      def process_tool(
        tool:,
        raw_context:,
        current_llm:,
        update_blk:,
        prompt:,
        context:,
        current_thinking:,
        execute: true
      )
        tool_call_id = tool.tool_call_id
        invocation_result =
          if execute
            invoke_tool(tool, context, &update_blk)
          else
            { error: "Not executed — tool batch or work limit reached." }
          end
        if context.server_owned_tools != false &&
             context.runtime_tools&.include?(Tools::ViewImage) &&
             current_llm.llm_model.delegated_vision? && tool.name != Tools::ViewImage.name
          image_references =
            extract_tool_image_references([invocation_result, tool.custom_raw]).uniq.first(
              MAX_DISCOVERED_IMAGE_REFERENCES,
            )
          available_images =
            register_tool_image_references(
              image_references,
              context,
              tool_image_guardian(context, tool),
            )
          if available_images.present? && invocation_result.is_a?(Hash)
            invocation_result = invocation_result.merge(available_images: available_images)
          end
        end
        invocation_result_json = invocation_result.to_json

        tool_call_message = {
          type: :tool_call,
          id: tool_call_id,
          content: { arguments: tool.parameters }.to_json,
          name: tool.name,
        }
        tool_call_message[:provider_data] = tool.provider_data if tool.provider_data.present?

        if current_thinking.present?
          thinking_message = nil
          provider_payload = {}

          current_thinking.each do |thinking|
            thinking_message = merge_thinking_message(thinking_message, thinking.message)
            provider_payload =
              DiscourseAi::Completions::Thinking.merge_provider_info(
                provider_payload,
                thinking.provider_info,
              )
          end

          tool_call_message[:thinking] = thinking_message if thinking_message
          tool_call_message[:thinking_provider_info] = provider_payload if provider_payload.present?
          current_thinking.clear
        end

        tool_message = {
          type: :tool,
          id: tool_call_id,
          content: invocation_result_json,
          name: tool.name,
        }
        tool_message[:provider_data] = tool.provider_data if tool.provider_data.present?

        prompt.push(**tool_call_message)
        prompt.push(**tool_message)
        evidence = tool.work_evidence(invocation_result)
        context.execution_context.work_budget.debit(
          current_llm.tokenizer.size(evidence),
          event_id: "tool:#{SecureRandom.uuid}",
        )

        raw_context << [
          tool_call_message[:content],
          tool_call_id,
          "tool_call",
          tool.name,
          nil,
          tool.provider_data.presence,
        ]
        raw_context << [invocation_result_json, tool_call_id, "tool", tool.name]
        invocation_result
      end

      def extract_tool_image_references(value, references = [])
        case value
        when Hash
          value.each_value { |nested| extract_tool_image_references(nested, references) }
        when Array
          value.each { |nested| extract_tool_image_references(nested, references) }
        when String
          references.concat(value.scan(%r{upload://[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]{1,10})?}))
        end
        references
      end

      def register_tool_image_references(references, context, guardian)
        references_by_sha1 =
          references.index_by { |short_url| Upload.sha1_from_short_url(short_url) }
        uploads_by_sha1 = Upload.where(sha1: references_by_sha1.keys.compact).index_by(&:sha1)
        system_secure_upload_ids =
          system_context_secure_upload_ids(uploads_by_sha1.values, context, guardian)

        references_by_sha1.filter_map do |sha1, short_url|
          upload = uploads_by_sha1[sha1]
          next if upload.blank?
          next if !DiscourseAi::Completions::UploadEncoder.supported_image_upload?(upload)
          next if !guardian.can_see_upload?(upload)
          if system_secure_upload_ids && upload.secure? &&
               !system_secure_upload_ids.include?(upload.id)
            next
          end

          context.register_image_upload(upload.id)
          short_url
        end
      end

      def system_context_secure_upload_ids(uploads, context, guardian)
        return if guardian.user&.id != Discourse.system_user.id

        access_control_post_ids = uploads.filter_map(&:access_control_post_id).uniq
        allowed_post_ids = [context.post_id, *context.context_post_ids].compact.map(&:to_i).to_set
        if context.topic_id.present? && access_control_post_ids.present?
          allowed_post_ids.merge(
            Post.where(id: access_control_post_ids, topic_id: context.topic_id).pluck(:id),
          )
        end

        uploads
          .filter_map do |upload|
            upload.id if upload.secure? && allowed_post_ids.include?(upload.access_control_post_id)
          end
          .to_set
      end

      def tool_image_guardian(context, tool)
        context.image_guardian(fallback_user: tool.bot_user || Discourse.system_user)
      end

      def invoke_tool(tool, context, &update_blk)
        if context.subagent_depth.to_i.positive? && tool_requires_approval?(tool)
          return(
            {
              status: "error",
              error: I18n.t("discourse_ai.ai_bot.subagent_errors.approval_unavailable"),
            }
          )
        end

        if tool_requires_approval?(tool)
          if (error = tool.validation_error)
            return error
          end
          return enqueue_tool_for_approval(tool, context, &update_blk)
        end

        if tool.invocation_limited? &&
             !context.reserve_tool_invocation(tool.name, limit: tool.max_invocations)
          return(
            {
              status: "error",
              error: I18n.t("discourse_ai.ai_bot.tool_errors.invocation_limit_reached"),
            }
          )
        end

        show_placeholder = !context.skip_show_thinking && !tool.class.allow_partial_tool_calls?

        update_blk.call("", build_placeholder(tool.summary, ""), :thinking) if show_placeholder

        result =
          tool.invoke do |progress, render_raw|
            if render_raw
              update_blk.call("", tool.custom_raw, :partial_invoke)
              show_placeholder = false
            elsif show_placeholder
              placeholder = build_placeholder(tool.summary, progress)
              update_blk.call("", placeholder, :thinking)
            end
          end

        if show_placeholder
          tool_details = build_placeholder(tool.summary, tool.details, custom_raw: tool.custom_raw)
          update_blk.call(tool_details, nil, :thinking)
        elsif tool.custom_raw.present?
          # we also rendered a placeholder for custom raw. Place something generic there
          tool_details = build_placeholder(tool.summary, tool.details, custom_raw: "")
          update_blk.call(tool_details, nil, :thinking)
          update_blk.call(tool.custom_raw, nil, :custom_raw)
        end

        result
      end

      def messages_to_raw_context(messages)
        messages
          .map do |message|
            case message[:type]
            when :tool_call
              [
                message[:content],
                message[:id],
                "tool_call",
                message[:name],
                thinking_context(message),
                message[:provider_data].presence,
              ]
            when :tool
              [message[:content], message[:id], "tool", message[:name]]
            when :user
              [message[:content], message[:id], "user"] if !transient_prompt_hint?(message)
            when :model
              [
                message[:content],
                nil,
                "model",
                nil,
                thinking_context(message),
                message[:provider_data].presence,
              ]
            end
          end
          .compact
      end

      def transient_prompt_hint?(message)
        message[:type] == :user && TRANSIENT_TOKEN_BUDGET_HINTS.include?(message[:content])
      end

      def thinking_context(message)
        if message[:thinking] || message[:thinking_provider_info]
          {
            "message" => message[:thinking],
            "provider_info" => message[:thinking_provider_info],
          }.compact
        end
      end

      def self.guess_model(bot_user)
        associated_llm = LlmModel.find_by(user_id: bot_user.id)

        return if associated_llm.nil? # Might be a agent user. Handled by constructor.

        associated_llm
      end

      def build_placeholder(summary, details, custom_raw: nil)
        # No nested details blocks - just output as plain text within thinking block
        placeholder = +"**#{summary}**\n#{details}\n\n"

        if custom_raw
          placeholder << custom_raw
          placeholder << "\n\n"
        end

        placeholder
      end
    end
  end
end
