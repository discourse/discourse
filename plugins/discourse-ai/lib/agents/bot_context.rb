# frozen_string_literal: true

module DiscourseAi
  module Agents
    class BotContext
      attr_accessor :messages,
                    :topic_id,
                    :post_id,
                    :private_message,
                    :custom_instructions,
                    :user,
                    :feature_context,
                    :skip_show_thinking,
                    :participants,
                    :chosen_tools,
                    :message_id,
                    :channel_id,
                    :context_post_ids,
                    :feature_name,
                    :resource_url,
                    :cancel_manager,
                    :inferred_concepts,
                    :format_dates,
                    :temporal_context,
                    :user_language,
                    :bypass_response_format,
                    :mcp_state,
                    :guardian,
                    :reviewable_id,
                    :server_owned_tools,
                    :runtime_tools,
                    :runtime_tools_llm_model_id,
                    :authorized_image_upload_ids,
                    :view_image_invocations,
                    :execution_context,
                    :subagent_execution_state,
                    :subagent_depth,
                    :parent_agent_id,
                    :current_agent_id,
                    :turn_token_budget,
                    :tool_invocation_counts,
                    :completion_limit_reached
      # these are strings that can be safely interpolated into templates
      TEMPLATE_PARAMS = %w[
        date
        time
        site_url
        site_title
        site_description
        participants
        username
        resource_url
        inferred_concepts
        user_language
        temporal_context
        top_categories
      ]

      def initialize(
        post: nil,
        topic: nil,
        participants: nil,
        user: nil,
        skip_show_thinking: nil,
        messages: [],
        custom_instructions: nil,
        feature_context: nil,
        site_url: nil,
        site_title: nil,
        site_description: nil,
        time: nil,
        message_id: nil,
        channel_id: nil,
        context_post_ids: nil,
        feature_name: "bot",
        resource_url: nil,
        cancel_manager: nil,
        inferred_concepts: [],
        format_dates: false,
        bypass_response_format: false,
        guardian: nil,
        server_owned_tools: true,
        execution_context: nil,
        subagent_execution_state: nil,
        subagent_depth: 0,
        parent_agent_id: nil,
        current_agent_id: nil,
        turn_token_budget: nil
      )
        @participants = participants
        @user = user
        @skip_show_thinking = skip_show_thinking
        @messages = messages
        @custom_instructions = custom_instructions
        @feature_context = feature_context || {}
        @format_dates = format_dates
        @completion_limit_reached = false

        @message_id = message_id
        @channel_id = channel_id
        @context_post_ids = context_post_ids

        @site_url = site_url
        @site_title = site_title
        @site_description = site_description
        @time = time
        @resource_url = resource_url

        @feature_name = feature_name
        @inferred_concepts = inferred_concepts

        @cancel_manager = cancel_manager

        @bypass_response_format = bypass_response_format
        @mcp_state = {}

        @guardian = guardian
        @server_owned_tools = server_owned_tools
        @execution_context = execution_context
        @subagent_execution_state = subagent_execution_state
        @subagent_depth = subagent_depth
        @parent_agent_id = parent_agent_id
        @current_agent_id = current_agent_id
        @turn_token_budget = turn_token_budget
        @tool_invocation_counts = Hash.new(0)
        @authorized_image_upload_ids = Set.new
        @view_image_invocations = 0

        if post
          @post_id = post.id
          @topic_id = post.topic_id
          @private_message = post.topic.private_message?
          @participants ||= post.topic.allowed_users.map(&:username).join(", ") if @private_message
          @user ||= post.user
        end

        if topic
          @topic_id ||= topic.id
          @private_message ||= topic.private_message?
          @participants ||= topic.allowed_users.map(&:username).join(", ") if @private_message
          @user ||= topic.user
        end
      end

      def reserve_tool_invocation(tool_name, limit:)
        limit = limit.to_i
        return true if limit <= 0
        return false if tool_invocation_limit_reached?(tool_name, limit: limit)

        tool_invocation_counts[tool_name.to_s] += 1
        true
      end

      def tool_invocation_limit_reached?(tool_name, limit:)
        limit = limit.to_i
        limit.positive? && tool_invocation_counts[tool_name.to_s] >= limit
      end

      def image_guardian(fallback_user: nil)
        guardian || Guardian.new(user || fallback_user)
      end

      def register_image_upload(upload_id)
        authorized_image_upload_ids << upload_id.to_i
      end

      def image_upload_authorized?(upload_id)
        authorized_image_upload_ids.include?(upload_id.to_i)
      end

      def lookup_template_param(key)
        public_send(key.to_sym) if TEMPLATE_PARAMS.include?(key)
      end

      def time
        @time ||= Time.zone.now
      end

      def date
        @date ||= time.strftime("%B %d, %Y")
      end

      def site_url
        @site_url ||= Discourse.base_url
      end

      def site_title
        @site_title ||= SiteSetting.title
      end

      def site_description
        @site_description ||= SiteSetting.site_description
      end

      def private_message?
        @private_message
      end

      def username
        @user&.username
      end

      def top_categories
        @top_categories ||=
          Category
            .where(read_restricted: false)
            .order(posts_year: :desc)
            .limit(10)
            .pluck(:name)
            .join(", ")
      end

      def to_json
        {
          messages: @messages,
          topic_id: @topic_id,
          post_id: @post_id,
          private_message: @private_message,
          custom_instructions: @custom_instructions,
          username: @user&.username,
          user_id: @user&.id,
          participants: @participants,
          chosen_tools: @chosen_tools,
          message_id: @message_id,
          channel_id: @channel_id,
          context_post_ids: @context_post_ids,
          site_url: @site_url,
          site_title: @site_title,
          site_description: @site_description,
          skip_show_thinking: @skip_show_thinking,
          feature_name: @feature_name,
          feature_context: @feature_context,
          resource_url: @resource_url,
          inferred_concepts: @inferred_concepts,
          user_language: @user_language,
          temporal_context: @temporal_context,
          top_categories: @top_categories,
          bypass_response_format: @bypass_response_format,
        }
      end

      def mcp_session_for(server_id)
        @mcp_state&.dig(server_id.to_i, :session_id)
      end

      def store_mcp_session(server_id, session_id)
        @mcp_state ||= {}
        state = (@mcp_state[server_id.to_i] ||= { session_id: nil })
        state[:session_id] = session_id
      end
    end
  end
end
