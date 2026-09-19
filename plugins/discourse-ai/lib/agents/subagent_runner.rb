# frozen_string_literal: true

module DiscourseAi
  module Agents
    class SubagentRunner
      MAX_SUBAGENT_DEPTH = 2
      MAX_PROMPT_LENGTH = 20_000
      MAX_RESULT_TOKENS = 30_000

      def self.resolve_model(agent_record)
        resolve_models([agent_record])[agent_record.id]
      end

      def self.resolve_models(agent_records)
        site_model_id = SiteSetting.ai_default_llm_model.presence&.to_i
        model_ids = agent_records.filter_map(&:default_llm_id)
        model_ids << site_model_id if site_model_id
        models_by_id = LlmModel.where(id: model_ids.uniq).index_by(&:id)

        agent_records.each_with_object({}) do |agent_record, result|
          model = models_by_id[agent_record.default_llm_id]
          model ||= models_by_id[site_model_id] if !agent_record.force_default_llm?
          result[agent_record.id] = model if model
        end
      end

      def initialize(parent_agent:, child_id:, prompt:, context:, parent_llm:)
        @parent_agent = parent_agent
        @child_id =
          if child_id.is_a?(Integer)
            child_id
          elsif child_id.is_a?(String) && child_id.match?(/\A-?\d+\z/)
            child_id.to_i
          end
        @prompt = prompt
        @context = context
        @parent_llm = parent_llm
      end

      def run
        child_record = nil
        validation = validate_request
        return validation if validation

        child_record = AiAgent.find_by(id: @child_id)
        child_class = child_record&.class_instance
        return error("unavailable_agent") if !usable_child?(child_record, child_class)

        model = self.class.resolve_model(child_record)
        return error("missing_model", child_record) if !model

        state = @context.subagent_execution_state
        return error("cancelled", child_record) if @context.cancel_manager&.cancelled?
        return error("token_limit", child_record) if state.remaining_tokens <= 0
        return error("call_limit", child_record) if !state.reserve_spawn

        yield(@prompt) if block_given?

        child_agent = child_class.new
        child_context = build_child_context(child_record, model)
        response = collect_response(child_agent, child_context, model)
        return error("completion_limit", child_record) if child_context.completion_limit_reached

        truncate_response(response, child_record)
      rescue => exception
        return error("cancelled", child_record) if @context.cancel_manager&.cancelled?

        Rails.logger.error(
          "DiscourseAi: subagent failed parent=#{@parent_agent.id} child=#{@child_id}: #{exception.class}: #{exception.message}",
        )
        error("execution_failed")
      end

      private

      def validate_request
        return error("invalid_agent") if @child_id.nil?
        return error("invalid_prompt") if !@prompt.is_a?(String) || @prompt.blank?
        return error("prompt_too_long") if @prompt.length > MAX_PROMPT_LENGTH
        return error("missing_user") if @context.user.nil?
        return error("depth_limit") if @context.subagent_depth.to_i >= MAX_SUBAGENT_DEPTH

        parent_record = AiAgent.find_by(id: @parent_agent.id)
        return error("unavailable_parent") if !parent_record
        return error("agent_not_allowed") if !parent_record.subagent_ids.include?(@child_id)
        return error("call_limit") if !@context.subagent_execution_state&.spawn_available?
        return error("completion_limit") if !@context.subagent_execution_state.completion_available?
        error("token_limit") if @context.subagent_execution_state.remaining_tokens <= 0
      end

      def usable_child?(child_record, child_class)
        return false if !child_record&.enabled? || !child_class
        return false if !@context.user.in_any_groups?(child_record.allowed_group_ids)
        return true if !child_record.system?

        required_tools = child_class.new.required_tools
        required_tools.empty? || (required_tools - Agent.all_available_tools).empty?
      end

      def build_child_context(child_record, model)
        child_depth = @context.subagent_depth.to_i + 1
        feature_context =
          @context.feature_context.to_h.merge(
            "subagent_parent_agent_id" => @parent_agent.id,
            "subagent_agent_id" => child_record.id,
            "subagent_depth" => child_depth,
          )
        child_budget =
          child_record.max_turn_tokens.presence ||
            Bot.default_max_turn_tokens(DiscourseAi::Completions::Llm.proxy(model))
        effective_budget = [child_budget, @context.subagent_execution_state.remaining_tokens].min

        child_context =
          BotContext.new(
            messages: [{ type: :user, content: @prompt }],
            participants: @context.participants,
            user: @context.user,
            skip_show_thinking: true,
            feature_context: feature_context,
            message_id: @context.message_id,
            channel_id: @context.channel_id,
            context_post_ids: @context.context_post_ids,
            feature_name: @context.feature_name,
            resource_url: @context.resource_url,
            site_url: @context.site_url,
            site_title: @context.site_title,
            site_description: @context.site_description,
            time: @context.time,
            cancel_manager: @context.cancel_manager,
            inferred_concepts: @context.inferred_concepts,
            format_dates: @context.format_dates,
            bypass_response_format: false,
            guardian: @context.guardian,
            server_owned_tools: @context.server_owned_tools,
            execution_context: @context.execution_context,
            subagent_execution_state: @context.subagent_execution_state,
            subagent_depth: child_depth,
            parent_agent_id: @parent_agent.id,
            current_agent_id: child_record.id,
            turn_token_budget: effective_budget,
          )
        child_context.topic_id = @context.topic_id
        child_context.post_id = @context.post_id
        child_context.private_message = @context.private_message?
        child_context.temporal_context = @context.temporal_context
        child_context.user_language = @context.user_language
        child_context
      end

      def collect_response(child_agent, child_context, model)
        streamed = +""
        structured = nil
        bot = Bot.as(@context.user, agent: child_agent, model: model)

        raw_context =
          bot.reply(
            child_context,
            execution_context: @context.execution_context,
          ) do |partial, _, type|
            if type == :structured_output
              structured = partial
            elsif type.blank? && partial.is_a?(String)
              streamed << partial
            end
          end

        return structured.to_s if structured

        final_response =
          raw_context.reverse.find do |entry|
            entry.is_a?(Array) && entry[2].nil? && entry.first.is_a?(String)
          end
        final_response&.first || streamed
      end

      def truncate_response(response, child_record)
        response = response.to_s
        tokenizer = @parent_llm.tokenizer
        truncated = tokenizer.size(response) > MAX_RESULT_TOKENS
        if truncated
          response =
            tokenizer.truncate(
              response,
              MAX_RESULT_TOKENS,
              strict: SiteSetting.ai_strict_token_counting,
            )
        end

        {
          status: "ok",
          agent_id: child_record.id,
          agent_name: child_record.class_instance.name,
          response: response,
          truncated: truncated,
        }
      end

      def error(key, child_record = nil)
        result = { status: "error", error: I18n.t("discourse_ai.ai_bot.subagent_errors.#{key}") }
        if child_record
          result[:agent_id] = child_record.id
          result[:agent_name] = child_record.class_instance.name
        elsif @child_id
          result[:agent_id] = @child_id
        end
        result
      end
    end
  end
end
