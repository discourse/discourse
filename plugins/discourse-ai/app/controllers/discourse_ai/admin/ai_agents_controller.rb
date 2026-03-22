# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiAgentsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :find_ai_agent, only: %i[edit update destroy create_user export]

      def index
        ai_agents =
          AiAgent
            .ordered
            .includes(:user, :uploads, ai_agent_mcp_servers: :ai_mcp_server)
            .map { |agent| LocalizedAiAgentSerializer.new(agent, root: false) }

        tools =
          DiscourseAi::Agents::Agent.all_available_tools.map do |tool|
            AiToolSerializer.new(tool, root: false)
          end

        AiTool
          .where(enabled: true)
          .each do |tool|
            tools << {
              id: "custom-#{tool.id}",
              name:
                I18n.t(
                  "discourse_ai.tools.custom_name",
                  name: tool.name.capitalize,
                  tool_name: tool.tool_name,
                ),
              token_count:
                DiscourseAi::Tokenizer::OpenAiCl100kTokenizer.size(tool.signature.to_json),
            }
          end

        llms = DiscourseAi::Configuration::LlmEnumerator.values_for_serialization
        mcp_servers =
          AiMcpServer
            .where(enabled: true)
            .order(:name)
            .map { |server| serialize_mcp_server(server) }

        sorted_tools = tools.sort_by { |t| t.try(:name) || t[:name] || "" }

        render json: {
                 ai_agents: ai_agents,
                 meta: {
                   tools: sorted_tools,
                   llms: llms,
                   mcp_servers: mcp_servers,
                   settings: {
                     rag_images_enabled: SiteSetting.ai_rag_images_enabled,
                   },
                 },
               }
      end

      def new
      end

      def edit
        render_ai_agent_resource(@ai_agent)
      end

      def create
        params = ai_agent_params
        mcp_server_ids = params.delete(:ai_mcp_server_ids)
        mcp_server_tool_names = params.delete(:mcp_server_tool_names) || {}
        ai_agent = AiAgent.new(params.except(:rag_uploads))

        if ai_agent.save
          if mcp_server_ids
            ai_agent.ai_mcp_server_ids = mcp_server_ids
            sync_mcp_server_tool_names(ai_agent, mcp_server_tool_names)
          end
          RagDocumentFragment.link_target_and_uploads(ai_agent, attached_upload_ids)
          log_ai_agent_creation(ai_agent)

          render_ai_agent_resource(ai_agent, status: :created)
        else
          render_json_error ai_agent
        end
      end

      def create_user
        user = @ai_agent.create_user!
        render json: BasicUserSerializer.new(user, root: "user")
      end

      def update
        params = ai_agent_params
        mcp_server_ids = params.delete(:ai_mcp_server_ids)
        mcp_server_tool_names = params.delete(:mcp_server_tool_names) || {}
        initial_attributes = @ai_agent.attributes.dup

        if @ai_agent.update(params.except(:rag_uploads))
          if mcp_server_ids
            @ai_agent.ai_mcp_server_ids = mcp_server_ids
            sync_mcp_server_tool_names(@ai_agent, mcp_server_tool_names)
          end
          RagDocumentFragment.update_target_uploads(@ai_agent, attached_upload_ids)
          log_ai_agent_update(@ai_agent, initial_attributes)

          render_ai_agent_resource(@ai_agent)
        else
          render_json_error @ai_agent
        end
      end

      def destroy
        agent_details = {
          agent_id: @ai_agent.id,
          name: @ai_agent.name,
          description: @ai_agent.description,
        }

        if @ai_agent.destroy
          log_ai_agent_deletion(agent_details)
          head :no_content
        else
          render_json_error @ai_agent
        end
      end

      def export
        agent = AiAgent.find(params[:id])
        exporter = DiscourseAi::AgentExporter.new(agent: agent)

        response.headers[
          "Content-Disposition"
        ] = "attachment; filename=\"#{agent.name.parameterize}.json\""

        render json: exporter.export
      end

      def import
        name = params.dig(:agent, :name) || params.dig(:persona, :name)
        existing_agent = AiAgent.find_by(name: name) if name.present?
        force_update = ActiveModel::Type::Boolean.new.cast(params[:force])
        import_payload = params.to_unsafe_h.except("controller", "action", "format", "force")

        begin
          importer = DiscourseAi::AgentImporter.new(json: import_payload)
          initial_attributes = existing_agent&.attributes&.dup if force_update

          if existing_agent && force_update
            agent = importer.import!(overwrite: true)
            log_ai_agent_update(agent, initial_attributes)
            render_ai_agent_resource(agent)
          else
            agent = importer.import!(overwrite: force_update)
            log_ai_agent_creation(agent)
            render_ai_agent_resource(agent, status: :created)
          end
        rescue DiscourseAi::AgentImporter::ImportError => e
          render_json_error e.message, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error("AI Agent import failed: #{e.message}")
          render_json_error "Import failed: #{e.message}", status: :unprocessable_entity
        end
      end

      def stream_reply
        custom_tools = nil
        tool_results = nil
        resume_token = params[:resume_token].to_s

        begin
          custom_tools = stream_reply_custom_tools
          tool_results = stream_reply_tool_results
        rescue ArgumentError => e
          return render_json_error e.message
        end

        if resume_token.present?
          # This is a best-effort fast-fail check. The token can still expire between this
          # check and async execution, which is handled again inside the session loader.
          if !DiscourseAi::AiBot::StreamReplyCustomToolsSession.resume_state_exists?(resume_token)
            return render_json_error(I18n.t("discourse_ai.errors.invalid_stream_resume_token"))
          end

          if tool_results.blank?
            return render_json_error(I18n.t("discourse_ai.errors.no_tool_results_specified"))
          end

          hijack = request.env["rack.hijack"]
          io = hijack.call

          DiscourseAi::AiBot::ResponseHttpStreamer.queue_streamed_reply(
            io: io,
            agent: nil,
            user: nil,
            topic: nil,
            query: "",
            custom_instructions: "",
            current_user: current_user,
            resume_token: resume_token,
            tool_results: tool_results,
          )
          return
        end

        agent_name = params[:agent_name].presence
        agent_id = params[:agent_id].presence

        agent = AiAgent.find_by(name: agent_name) || AiAgent.find_by(id: agent_id)
        return render_json_error(I18n.t("discourse_ai.errors.agent_not_found")) if agent.nil?

        return render_json_error(I18n.t("discourse_ai.errors.agent_disabled")) if !agent.enabled

        if agent.default_llm.blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_default_llm"))
        end

        if params[:query].blank?
          return render_json_error(I18n.t("discourse_ai.errors.no_query_specified"))
        end

        return render_json_error(I18n.t("discourse_ai.errors.no_user_for_agent")) if !agent.user_id

        if !params[:username] && !params[:user_unique_id]
          return render_json_error(I18n.t("discourse_ai.errors.no_user_specified"))
        end

        user = nil

        if params[:username]
          user = User.find_by_username(params[:username])
          return render_json_error(I18n.t("discourse_ai.errors.user_not_found")) if user.nil?
        elsif params[:user_unique_id]
          user = stage_user
        end

        raise Discourse::NotFound if user.nil?

        topic_id = params[:topic_id].to_i
        topic = nil

        if topic_id > 0
          topic = Topic.find(topic_id)

          if topic.topic_allowed_users.where(user_id: user.id).empty?
            return render_json_error(I18n.t("discourse_ai.errors.user_not_allowed"))
          end
        end

        hijack = request.env["rack.hijack"]
        io = hijack.call

        DiscourseAi::AiBot::ResponseHttpStreamer.queue_streamed_reply(
          io: io,
          agent: agent,
          user: user,
          topic: topic,
          query: params[:query].to_s,
          custom_instructions: params[:custom_instructions].to_s,
          current_user: current_user,
          custom_tools: custom_tools,
        )
      end

      private

      AI_STREAM_CONVERSATION_UNIQUE_ID = "ai-stream-conversation-unique-id"
      MAX_STREAM_REPLY_CUSTOM_TOOLS = 20
      MAX_STREAM_REPLY_TOOL_RESULTS = 20
      MAX_STREAM_REPLY_CUSTOM_TOOL_DEFINITION_BYTES = 10_000
      MAX_STREAM_REPLY_TOOL_RESULT_CONTENT_BYTES = 100 * 1024

      def stage_user
        unique_id = params[:user_unique_id].to_s
        field = UserCustomField.find_by(name: AI_STREAM_CONVERSATION_UNIQUE_ID, value: unique_id)

        if field
          field.user
        else
          preferred_username = params[:preferred_username]
          username = UserNameSuggester.suggest(preferred_username || unique_id)

          user =
            User.new(
              username: username,
              email: "#{SecureRandom.hex}@invalid.com",
              staged: true,
              active: false,
            )
          user.custom_fields[AI_STREAM_CONVERSATION_UNIQUE_ID] = unique_id
          user.save!
          user
        end
      end

      def stream_reply_custom_tools
        return [] if !params.key?(:custom_tools)

        raw_tools = params[:custom_tools]
        return [] if raw_tools.blank?

        if !raw_tools.is_a?(Array)
          raise ArgumentError,
                I18n.t(
                  "discourse_ai.errors.invalid_custom_tools",
                  details: I18n.t("discourse_ai.errors.expected_array"),
                )
        end

        if raw_tools.size > MAX_STREAM_REPLY_CUSTOM_TOOLS
          raise ArgumentError,
                I18n.t(
                  "discourse_ai.errors.too_many_custom_tools",
                  max: MAX_STREAM_REPLY_CUSTOM_TOOLS,
                )
        end

        parsed =
          raw_tools.map do |tool|
            hash = normalize_hash_param(tool, key: :custom_tools)
            parameters = hash["parameters"]
            hash["parameters"] = parameters.reject(&:blank?) if parameters.is_a?(Array)
            definition = nil
            begin
              definition =
                DiscourseAi::Completions::ToolDefinition.from_hash(hash.deep_symbolize_keys)
            rescue ArgumentError, NoMethodError => e
              raise ArgumentError,
                    I18n.t("discourse_ai.errors.invalid_custom_tools", details: e.message)
            end
            definition_hash = definition.to_h.stringify_keys
            if definition_hash.to_json.bytesize > MAX_STREAM_REPLY_CUSTOM_TOOL_DEFINITION_BYTES
              raise ArgumentError,
                    I18n.t(
                      "discourse_ai.errors.custom_tool_definition_too_large",
                      max: MAX_STREAM_REPLY_CUSTOM_TOOL_DEFINITION_BYTES,
                    )
            end
            definition_hash
          end

        names = parsed.map { |tool| tool["name"] }
        duplicate_names = names.tally.select { |_, count| count > 1 }.keys
        if duplicate_names.present?
          raise ArgumentError,
                I18n.t(
                  "discourse_ai.errors.duplicate_custom_tools",
                  names: duplicate_names.join(", "),
                )
        end

        parsed
      end

      def stream_reply_tool_results
        if params.key?(:tool_results) && params.key?(:tool_result)
          raise ArgumentError, I18n.t("discourse_ai.errors.ambiguous_tool_results")
        end

        raw_results = params.key?(:tool_results) ? params[:tool_results] : params[:tool_result]
        return [] if raw_results.blank?

        raw_results = [raw_results] if !raw_results.is_a?(Array)

        if raw_results.size > MAX_STREAM_REPLY_TOOL_RESULTS
          raise ArgumentError,
                I18n.t(
                  "discourse_ai.errors.too_many_tool_results",
                  max: MAX_STREAM_REPLY_TOOL_RESULTS,
                )
        end

        raw_results.map do |tool_result|
          hash = normalize_hash_param(tool_result, key: :tool_results)
          id = hash["tool_call_id"].presence || hash["id"].presence
          if id.blank?
            raise ArgumentError,
                  I18n.t("discourse_ai.errors.invalid_tool_results", details: "tool_call_id")
          end

          if !hash.key?("content")
            raise ArgumentError,
                  I18n.t("discourse_ai.errors.invalid_tool_results", details: "content")
          end

          content = hash["content"]
          if content.nil?
            raise ArgumentError,
                  I18n.t("discourse_ai.errors.invalid_tool_results", details: "content")
          end
          content_bytesize = content.is_a?(String) ? content.bytesize : content.to_json.bytesize

          if content_bytesize > MAX_STREAM_REPLY_TOOL_RESULT_CONTENT_BYTES
            raise ArgumentError,
                  I18n.t(
                    "discourse_ai.errors.tool_result_content_too_large",
                    max: MAX_STREAM_REPLY_TOOL_RESULT_CONTENT_BYTES,
                  )
          end

          { "tool_call_id" => id.to_s, "content" => content }
        rescue JSON::GeneratorError
          raise ArgumentError,
                I18n.t("discourse_ai.errors.invalid_tool_results", details: "content")
        end
      end

      def normalize_hash_param(raw, key:)
        hash = raw
        hash = hash.to_unsafe_h if hash.is_a?(ActionController::Parameters)

        if !hash.is_a?(Hash)
          raise ArgumentError,
                I18n.t(
                  "discourse_ai.errors.invalid_stream_param",
                  key: key,
                  details: I18n.t("discourse_ai.errors.expected_object"),
                )
        end

        hash.stringify_keys
      end

      def find_ai_agent
        @ai_agent = AiAgent.find(params[:id])
      end

      def attached_upload_ids
        ai_agent_params[:rag_uploads].to_a.map { |h| h[:id] }
      end

      def ai_agent_params
        payload = ai_agent_payload
        permitted =
          payload.permit(
            :name,
            :description,
            :enabled,
            :system_prompt,
            :priority,
            :top_p,
            :temperature,
            :default_llm_id,
            :user_id,
            :max_context_posts,
            :vision_enabled,
            :vision_max_pixels,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_conversation_chunks,
            :rag_llm_model_id,
            :question_consolidator_llm_id,
            :allow_chat_channel_mentions,
            :allow_chat_direct_messages,
            :allow_topic_mentions,
            :allow_personal_messages,
            :show_thinking,
            :forced_tool_count,
            :force_default_llm,
            :execution_mode,
            :max_turn_tokens,
            :compression_threshold,
            :require_approval,
            allowed_group_ids: [],
            mcp_server_ids: [],
            rag_uploads: [:id],
          )

        if payload[:mcp_server_ids].is_a?(Array)
          permitted[:ai_mcp_server_ids] = payload[:mcp_server_ids].filter_map(&:presence).map(
            &:to_i
          )
          permitted.delete(:mcp_server_ids)
        end

        permitted[:mcp_server_tool_names] = normalize_mcp_server_tool_names(
          payload[:mcp_server_tool_names],
          permitted[:ai_mcp_server_ids],
        )

        if tools = payload[:tools]
          permitted[:tools] = permit_tools(tools)
        end

        if response_format = payload[:response_format]
          permitted[:response_format] = permit_response_format(response_format)
        end

        if examples = payload[:examples]
          permitted[:examples] = permit_examples(examples)
        end

        permitted
      end

      def ai_agent_payload
        payload = params[:ai_agent]
        raise ActionController::ParameterMissing.new(:ai_agent) if payload.blank?

        if payload.is_a?(ActionController::Parameters)
          payload
        else
          ActionController::Parameters.new(payload)
        end
      end

      def render_ai_agent_resource(agent, status: :ok)
        serialized = LocalizedAiAgentSerializer.new(agent, root: false)
        render json: { ai_agent: serialized }, status: status
      end

      def permit_tools(tools)
        return [] if !tools.is_a?(Array)

        tools.filter_map do |tool, options, force_tool|
          break nil if !tool.is_a?(String)
          options&.permit! if options && options.is_a?(ActionController::Parameters)

          # this is simpler from a storage perspective, 1 way to store tools
          [tool, options, !!force_tool]
        end
      end

      def permit_response_format(response_format)
        return [] if !response_format.is_a?(Array)

        response_format.map do |element|
          if element && element.is_a?(ActionController::Parameters)
            element.permit!
          else
            false
          end
        end
      end

      def permit_examples(examples)
        return [] if !examples.is_a?(Array)

        examples.map { |example_arr| example_arr.take(2).map(&:to_s) }
      end

      def normalize_mcp_server_tool_names(raw_tool_names, allowed_server_ids)
        return {} if !raw_tool_names.respond_to?(:to_unsafe_h) && !raw_tool_names.is_a?(Hash)

        allowed_ids = Array(allowed_server_ids).map(&:to_i).to_set
        raw_hash =
          if raw_tool_names.respond_to?(:to_unsafe_h)
            raw_tool_names.to_unsafe_h
          else
            raw_tool_names
          end

        raw_hash.each_with_object({}) do |(server_id, tool_names), hash|
          normalized_server_id = server_id.to_i
          next if !allowed_ids.include?(normalized_server_id)
          next if !tool_names.is_a?(Array)

          normalized_tool_names = tool_names.filter_map { |name| name.to_s.presence }.uniq
          next if normalized_tool_names.blank?

          hash[normalized_server_id.to_s] = normalized_tool_names
        end
      end

      def sync_mcp_server_tool_names(ai_agent, mcp_server_tool_names)
        ai_agent.ai_agent_mcp_servers.each do |assignment|
          assignment.update!(
            selected_tool_names: mcp_server_tool_names[assignment.ai_mcp_server_id.to_s],
          )
        end
      end

      def serialize_mcp_server(server)
        {
          id: server.id,
          name: server.name,
          tool_count: server.tool_count,
          token_count: server.token_count,
          last_health_status: server.last_health_status,
          last_checked_at: server.last_checked_at,
          tools: server.tools_for_serialization,
        }
      end

      def ai_agent_logger_fields
        {
          name: {
          },
          description: {
          },
          enabled: {
          },
          priority: {
          },
          system_prompt: {
            type: :large_text,
          },
          default_llm_id: {
          },
          temperature: {
          },
          top_p: {
          },
          user_id: {
          },
          max_context_posts: {
          },
          vision_enabled: {
          },
          vision_max_pixels: {
          },
          rag_chunk_tokens: {
          },
          rag_chunk_overlap_tokens: {
          },
          rag_conversation_chunks: {
          },
          rag_llm_model_id: {
          },
          question_consolidator_llm_id: {
          },
          allow_chat_channel_mentions: {
          },
          allow_chat_direct_messages: {
          },
          allow_topic_mentions: {
          },
          allow_personal_messages: {
          },
          show_thinking: {
            type: :large_text,
          },
          forced_tool_count: {
          },
          force_default_llm: {
          },
          execution_mode: {
          },
          max_turn_tokens: {
          },
          compression_threshold: {
          },
          require_approval: {
          },
          # JSON fields
          json_fields: %i[tools response_format examples allowed_group_ids ai_mcp_server_ids],
        }
      end

      def log_ai_agent_creation(ai_agent)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { agent_id: ai_agent.id, subject: ai_agent.name }
        entity_details[:tools_count] = (ai_agent.tools || []).size

        logger.log_creation("agent", ai_agent, ai_agent_logger_fields, entity_details)
      end

      def log_ai_agent_update(ai_agent, initial_attributes)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { agent_id: ai_agent.id, subject: ai_agent.name }
        entity_details[:tools_count] = ai_agent.tools.size if ai_agent.tools.present?

        logger.log_update(
          "agent",
          ai_agent,
          initial_attributes,
          ai_agent_logger_fields,
          entity_details,
        )
      end

      def log_ai_agent_deletion(agent_details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        agent_details[:subject] = agent_details[:name]

        logger.log_deletion("agent", agent_details)
      end
    end
  end
end
