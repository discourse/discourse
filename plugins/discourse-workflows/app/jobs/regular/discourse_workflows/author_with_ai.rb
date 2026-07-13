# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class AuthorWithAi < ::Jobs::Base
      sidekiq_options retry: false

      AI_RESPONSE_STATUSES = %w[needs_clarification proposed_patch explanation error].freeze
      TRIGGER_AUTHOR_FIELD_FACTS = [
        "trigger:topic_created exposes the topic creator/first-post author under post.* and does not expose a top-level user object. Use exact paths such as post.username for the username, post.user_id for the user ID, and post.post_url for a link to the post.",
        "trigger:post_created exposes the created post under post.* and the post author under user.*. Use exact paths such as user.trust_level for trust-level checks, user.username for the username, user.id for the user ID, user.admin/user.moderator/user.staff for staff checks, and post.post_url for a link to the post.",
        "For generic requests like 'when someone posts' or 'when anyone posts', trigger:post_created covers all regular posts, including first posts and replies. Do not ask to distinguish replies from topic starters unless the request explicitly says replies only or new topics only.",
        "trigger:topic_closed exposes only the closed topic under topic.*. When a closed-topic workflow needs a first-post link, add action:topic with operation get and topic_id ={{ $json.topic.id }} immediately after the trigger. Use the exact fields returned by workflow_validate_patch for any first-post author data; do not assume post.trust_level is available.",
        "Do not ask whether trust level is available for trigger:post_created or trigger:post_edited; it is available as user.trust_level.",
        "Do not generate fallback chains for undocumented author aliases; use the exact post.* fields from the node catalog output_contracts.",
        "trigger:user_added_to_group and trigger:user_removed_from_group expose the affected user under user.*, the selected group under group.*, and event metadata under membership.*. Use user.username for the affected username and membership.action to distinguish added vs removed if needed.",
        "For named group membership checks, use workflow_resolve_entity to resolve the group, then use action:group with operation check_membership, group_id set to the resolved group id, and username ={{ $json.user.username }} when the input schema includes user.username, otherwise use the exact username field from the current input schema. It adds group_membership.in_group while preserving the original item fields. Do not use a Code node for simple group membership.",
        "For personal messages, private messages, DMs, direct messages, or PM notifications, use action:send_personal_message with recipient_usernames or recipient_group_names as arrays, title, raw, and sender_username. Resolve named users with workflow_resolve_entity(kind: user), and named groups with workflow_resolve_entity(kind: group).",
      ].freeze

      def execute(args)
        @generation_id = args[:generation_id]
        @session = ::DiscourseWorkflows::AiAuthoringSession.find_by(id: args[:session_id])
        @user = User.find_by(id: args[:user_id])
        return if @session.blank? || @user.blank?
        if !::DiscourseWorkflows::AiAuthoringEnqueuer.enabled?
          return publish_error(I18n.t("discourse_workflows.ai.error_not_enabled"))
        end

        publish_progress(:loading_context)
        agent_record = find_agent_record
        if agent_record.blank?
          return publish_error(I18n.t("discourse_workflows.ai.error_agent_not_configured"))
        end

        publish_progress(:planning)
        parsed = run_agent(agent_record)

        if proposed_patch_response?(parsed) && code_scripts_present?(parsed)
          publish_progress(:writing_scripts)
          publish_progress(:validating_scripts)
          parsed = validate_script_proposals(parsed)
        end

        if proposed_patch_response?(parsed)
          publish_progress(:validating_patch)
          parsed = validate_patch_proposal(parsed)
        end

        publish_progress(:summarizing)
        persist_response(parsed)
        publish_terminal(parsed)
      rescue => e
        publish_error(e.message)
      end

      private

      def find_agent_record
        configured_agent_id = SiteSetting.discourse_workflows_workflow_authoring_agent.to_i
        default_agent_id =
          ::DiscourseAi::Agents::Agent.external_agent_id(::DiscourseWorkflows::AiWorkflowAuthor)

        AiAgent.find_by(id: configured_agent_id) || AiAgent.find_by(id: default_agent_id)
      end

      def run_agent(agent_record)
        agent_klass = agent_record.class_instance
        bot = ::DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_klass.new)
        context =
          ::DiscourseAi::Agents::BotContext.new(
            messages: normalized_session_messages,
            user: @user,
            feature_name: "discourse_workflows_workflow_authoring",
            custom_instructions: authoring_context_instructions,
            bypass_response_format: true,
          )

        result = +""
        raw_context =
          bot.reply(context) do |partial, raw, type|
            publish_agent_stream_progress(partial, raw, type)

            result << partial if type.blank? && partial.is_a?(String)
          end
        append_raw_context_text(result, raw_context)

        parse_response(result, raw_context)
      end

      def append_raw_context_text(result, raw_context)
        return if result.present? || raw_context.blank?

        raw_context.each do |entry|
          next if !entry.is_a?(Array) || !entry.first.is_a?(String)
          next if entry[2].present?

          result << entry.first
        end
      end

      def normalized_session_messages
        @session.messages.map do |message|
          normalized_message = message.symbolize_keys.slice(:type, :content)
          normalized_message[:type] = normalized_message[:type].to_sym if normalized_message[:type]
          normalized_message
        end
      end

      def authoring_context_instructions
        context_tools = {
          workflow_node_catalog:
            "Call this with targeted queries for node parameters, output contracts, capabilities, and examples.",
          workflow_ai_agent_catalog:
            "Call this before adding action:ai_agent nodes to find existing enabled AI agents to reuse. If none fit, propose create_ai_agent with name, description, and system_prompt.",
          workflow_graph_context:
            "Call this with workflow_id when you need the current graph nodes and connections.",
          workflow_validate_patch:
            "Call this to dry-run candidate operations and inspect inferred node_fields.",
          workflow_script_context:
            "Call this before writing Code node JavaScript to inspect the runtime API and mode rules.",
          workflow_validate_script:
            "Call this with exact Code node mode and code; repair any errors before returning a proposal.",
          workflow_authoring_result:
            "Call this exactly once when authoring is complete; it is the final response.",
        }
        if ::DiscourseWorkflows::Ai::Tools::SearchChatChannels.available?
          context_tools[
            :search_chat_channels
          ] = "Call this before asking the admin to choose a chat channel or before setting action:send_chat_message channel_id. Use returned matches; never invent channel names or IDs."
        end

        payload = {
          workflow: workflow_summary,
          trigger_author_field_facts: TRIGGER_AUTHOR_FIELD_FACTS,
          context_tools: context_tools,
        }

        <<~TEXT
          Important workflow field facts:
          #{TRIGGER_AUTHOR_FIELD_FACTS.map { |fact| "- #{fact}" }.join("\n")}

          Compact workflow authoring context. Full graph and node catalog are intentionally not preloaded; use workflow_graph_context and workflow_node_catalog tools for details:
          #{JSON.generate(payload)}
        TEXT
      end

      def workflow_summary
        workflow = @session.workflow
        return nil if workflow.blank?

        nodes = workflow.nodes || []
        connection_count =
          ::DiscourseWorkflows::WorkflowDocument.connection_records(
            nodes,
            workflow.connections || {},
          ).length

        {
          id: workflow.id,
          name: workflow.name,
          node_count: nodes.length,
          connection_count: connection_count,
          published: workflow.published?,
          has_unpublished_changes: workflow.has_unpublished_changes?,
          version_id: workflow.version_id,
          active_version_id: workflow.active_version_id,
          graph_digest: ::DiscourseWorkflows::Ai::GraphDigest.call(workflow),
        }
      end

      def parse_response(text, raw_context = [])
        parsed = parse_tool_call_response(raw_context)
        return parsed if parsed.present?

        invalid_response(text)
      end

      def parse_json_hash(candidate)
        parsed = JSON.parse(candidate)
        parsed if parsed.is_a?(Hash)
      rescue JSON::ParserError, Oj::ParseError
        nil
      end

      def parse_tool_call_response(raw_context)
        authoring_response = parse_authoring_result_tool_response(raw_context)
        if invalid_empty_proposed_patch_response?(authoring_response)
          patch_response = parse_validate_patch_tool_response(raw_context)
          return patch_response if patch_response.present?
        end

        authoring_response || parse_ask_questions_tool_response(raw_context) ||
          parse_validate_patch_tool_response(raw_context)
      end

      def parse_authoring_result_tool_response(raw_context)
        Array
          .wrap(raw_context)
          .reverse_each do |entry|
            next if !workflow_authoring_result_tool_entry?(entry)

            parsed = authoring_result_from_tool_entry(entry)
            next if parsed.blank?

            parsed = normalize_ai_response(parsed)
            return parsed if meaningful_ai_response?(parsed)
          end

        nil
      end

      def authoring_result_from_tool_entry(entry)
        content = parse_json_hash(entry.first.to_s)
        if entry[2].to_s == "tool_call"
          normalized_hash(content&.fetch("arguments", nil))
        else
          normalized_hash(content)
        end
      end

      def workflow_authoring_result_tool_entry?(entry)
        entry.is_a?(Array) && %w[tool_call tool].include?(entry[2].to_s) &&
          entry[3].to_s == ::DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult.name
      end

      def parse_ask_questions_tool_response(raw_context)
        Array
          .wrap(raw_context)
          .reverse_each do |entry|
            next if !workflow_ask_questions_tool_entry?(entry)

            content = parse_json_hash(entry.first.to_s)
            questions = ask_questions_from_tool_entry(entry, content)
            next if questions.blank?

            return(
              {
                "status" => "needs_clarification",
                "message" => I18n.t("discourse_workflows.ai.clarification_message"),
                "questions" => json_safe(questions),
                "proposal" => {
                },
              }
            )
          end

        nil
      end

      def ask_questions_from_tool_entry(entry, content)
        if entry[2].to_s == "tool_call"
          normalized_hash(content&.fetch("arguments", nil))[:questions]
        else
          normalized_hash(content)[:questions]
        end
      end

      def workflow_ask_questions_tool_entry?(entry)
        entry.is_a?(Array) && %w[tool_call tool].include?(entry[2].to_s) &&
          entry[3].to_s == ::DiscourseWorkflows::Ai::Tools::WorkflowAskQuestions.name
      end

      def parse_validate_patch_tool_response(raw_context)
        Array
          .wrap(raw_context)
          .reverse_each do |entry|
            next if !workflow_validate_patch_tool_call?(entry)

            content = parse_json_hash(entry.first.to_s)
            arguments = normalized_hash(content&.fetch("arguments", nil))
            operations = Array.wrap(arguments[:operations])
            next if operations.blank?

            return tool_call_proposal_response(arguments, operations)
          end

        nil
      end

      def workflow_validate_patch_tool_call?(entry)
        entry.is_a?(Array) && entry[2].to_s == "tool_call" &&
          entry[3].to_s == ::DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch.name
      end

      def tool_call_proposal_response(arguments, operations)
        operations = normalized_patch_operations(operations)
        title =
          arguments[:workflow_name].presence || human_request_title ||
            I18n.t("discourse_workflows.ai.tool_call_proposal_title")

        {
          "status" => "proposed_patch",
          "message" => I18n.t("discourse_workflows.ai.tool_call_proposal_message"),
          "questions" => [],
          "proposal" => {
            "title" => title,
            "summary" =>
              I18n.t("discourse_workflows.ai.tool_call_proposal_summary", count: operations.size),
            "risk_level" => arguments[:risk_level].presence || "medium",
            "operations" => json_safe(operations),
          },
        }
      end

      def normalize_ai_response(parsed)
        parsed = normalized_hash(parsed)
        proposal = normalized_hash(parsed[:proposal])
        status = parsed[:status].to_s
        status = "proposed_patch" if status.blank? && proposal[:operations].present?

        {
          "status" => status,
          "message" => parsed[:message].presence || parsed[:error].presence,
          "questions" => Array.wrap(parsed[:questions]),
          "proposal" => proposal,
        }
      end

      def meaningful_ai_response?(parsed)
        parsed = normalized_hash(parsed)
        proposal = normalized_hash(parsed[:proposal])

        status = parsed[:status].to_s
        if status == "proposed_patch"
          proposal[:operations].present?
        else
          AI_RESPONSE_STATUSES.include?(status) || proposal[:operations].present?
        end
      end

      def invalid_response(text)
        {
          "status" => "error",
          "message" => text.presence || I18n.t("discourse_workflows.ai.error_invalid_response"),
        }
      end

      def invalid_empty_proposed_patch_response?(parsed)
        parsed = normalized_hash(parsed)
        tool_class = ::DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult
        missing_operations_message = tool_class::MISSING_PROPOSAL_OPERATIONS_MESSAGE

        parsed[:status].to_s == "error" && parsed[:proposal].blank? &&
          parsed[:message].to_s == missing_operations_message
      end

      def human_request_title
        human_request = latest_human_request
        human_request.presence&.truncate(80)
      end

      def latest_human_request
        requests = [@session.latest_request]
        @session.messages.reverse_each do |message|
          next if message["type"].to_s != "user"

          requests << user_message_text(message["content"])
        end

        requests.find { |request| request.present? && !clarification_result_message?(request) }
      end

      def user_message_text(content)
        parsed = parse_json_hash(content.to_s)
        normalized_hash(parsed)[:message].presence || content.to_s
      end

      def clarification_result_message?(message)
        parsed = parse_json_hash(message.to_s)
        normalized_hash(parsed)[:type].to_s == "workflow_ask_questions_result"
      end

      def proposed_patch_response?(parsed)
        parsed["status"].to_s == "proposed_patch"
      end

      def validate_script_proposals(parsed)
        proposal = proposal_for(parsed)
        operations = normalized_patch_operations(proposal[:operations])
        proposal["operations"] = operations
        validations = code_script_validations(operations)
        proposal["script_validations"] = validations if validations.present?

        if validations.any? { |validation| !validation["valid"] }
          return(
            parsed.merge(
              "status" => "error",
              "message" => invalid_script_message(validations),
              "proposal" => json_safe(proposal),
            )
          )
        end

        parsed.merge("proposal" => json_safe(proposal))
      end

      def validate_patch_proposal(parsed)
        proposal = proposal_for(parsed)
        operations = normalized_patch_operations(proposal[:operations])
        proposal["operations"] = operations

        if operations.blank?
          return(
            parsed.merge(
              "status" => "error",
              "message" => I18n.t("discourse_workflows.ai.error_no_operations"),
              "proposal" => json_safe(proposal),
            )
          )
        end

        validation = validate_patch_operations(proposal, operations)
        proposal["patch_validation"] = validation
        proposal["created_resources"] = validation["created_resources"] if validation[
          "created_resources"
        ].present?

        if !validation["valid"]
          return(
            parsed.merge(
              "status" => "error",
              "message" =>
                I18n.t(
                  "discourse_workflows.ai.error_invalid_patch",
                  errors: validation["errors"].join(", "),
                ),
              "proposal" => json_safe(proposal),
            )
          )
        end

        parsed.merge("proposal" => json_safe(proposal))
      end

      def code_scripts_present?(parsed)
        operations = normalized_patch_operations(proposal_for(parsed)[:operations])
        operations.any? do |operation|
          code_script_for_operation(normalized_hash(operation)).present?
        end
      end

      def invalid_script_message(validations)
        details =
          validations
            .select { |validation| !validation["valid"] }
            .flat_map do |validation|
              node_name =
                validation["node_name"].presence ||
                  I18n.t("discourse_workflows.ai.default_code_node_name")
              Array.wrap(validation["errors"]).map { |error| "#{node_name}: #{error}" }
            end
            .join("; ")

        if details.present?
          I18n.t("discourse_workflows.ai.error_invalid_script_with_errors", errors: details)
        else
          I18n.t("discourse_workflows.ai.error_invalid_script")
        end
      end

      def code_script_validations(operations)
        operations.each_with_index.filter_map do |operation, index|
          script = code_script_for_operation(normalized_hash(operation))
          next if script.blank?

          result = validate_code_script(script)
          {
            "operation_index" => index,
            "node_name" => script[:node_name],
            "mode" => script[:mode],
            "valid" => result[:valid],
            "errors" => result[:errors] || [],
            "warnings" => result[:warnings] || [],
          }
        end
      end

      def code_script_for_operation(operation)
        case operation[:op].to_s
        when "add_node"
          code_script_for_added_node(operation)
        when "update_node_parameters"
          code_script_for_parameter_update(operation)
        end
      end

      def code_script_for_added_node(operation)
        node = normalized_hash(operation[:node])
        return if node[:type].to_s != "action:code"

        parameters = normalized_hash(node[:parameters])
        {
          node_name:
            node[:name].presence || I18n.t("discourse_workflows.ai.default_code_node_name"),
          mode: code_mode(parameters),
          code: parameters[:code].to_s,
        }
      end

      def code_script_for_parameter_update(operation)
        parameters = normalized_hash(operation[:parameters])
        return if !parameters.key?(:code) && !parameters.key?(:mode)

        node = @session.workflow&.find_node(operation[:node_id] || operation[:client_id])
        return if node.blank? && !parameters.key?(:code)
        return if node.present? && node["type"] != "action:code" && !parameters.key?(:code)

        existing_parameters = node ? ::DiscourseWorkflows::NodeData.parameters(node) : {}
        {
          node_name:
            node&.dig("name").presence || I18n.t("discourse_workflows.ai.default_code_node_name"),
          mode: code_mode(parameters, existing_parameters),
          code: (parameters.key?(:code) ? parameters[:code] : existing_parameters["code"]).to_s,
        }
      end

      def validate_code_script(script)
        context = ::DiscourseAi::Agents::BotContext.new(messages: [], user: @user)
        ::DiscourseWorkflows::Ai::Tools::WorkflowValidateScript.new(
          { mode: script[:mode], code: script[:code] },
          bot_user: Discourse.system_user,
          llm: nil,
          context: context,
        ).invoke
      end

      def code_mode(parameters, existing_parameters = {})
        (
          parameters[:mode].presence || existing_parameters["mode"].presence ||
            ::DiscourseWorkflows::Ai::Tools::WorkflowValidateScript::RUN_ONCE_FOR_ALL_ITEMS
        ).to_s
      end

      def validate_patch_operations(proposal, operations)
        result =
          ::DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch.new(
            {
              workflow_id: @session.workflow_id,
              workflow_name:
                proposal[:workflow_name].presence || @session.workflow&.name ||
                  @session.latest_request.to_s.truncate(100),
              operations: operations,
            }.compact,
            bot_user: Discourse.system_user,
            llm: nil,
            context: ::DiscourseAi::Agents::BotContext.new(messages: [], user: @user),
          ).invoke

        {
          "valid" => result[:valid],
          "errors" => Array.wrap(result[:errors]),
          "graph_errors" => Array.wrap(result[:graph_errors]),
          "expression_errors" => Array.wrap(result[:expression_errors]),
          "diff" => result[:diff],
          "created_resources" => Array.wrap(result[:created_resources]),
        }
      end

      def proposal_for(parsed)
        proposal = parsed["proposal"]
        proposal.is_a?(Hash) ? proposal.with_indifferent_access : {}.with_indifferent_access
      end

      def normalized_patch_operations(operations)
        Array
          .wrap(operations)
          .map do |operation|
            if operation.is_a?(String)
              parse_json_hash(operation.strip) || operation
            else
              operation
            end
          end
      end

      def normalized_hash(value)
        value.respond_to?(:to_h) ? value.to_h.with_indifferent_access : {}.with_indifferent_access
      end

      def persist_response(parsed)
        status = parsed["status"].to_s
        session_status =
          case status
          when "needs_clarification"
            "needs_clarification"
          when "proposed_patch"
            "proposal_ready"
          when "error"
            "error"
          else
            "drafting"
          end

        @session.update!(
          status: session_status,
          latest_response: parsed,
          proposed_patch: parsed["proposal"] || {},
          risk_level: proposal_for(parsed)["risk_level"],
        )
      end

      def publish_terminal(parsed)
        status = parsed["status"].presence || "error"
        ::DiscourseWorkflows::Ai::ProgressPublisher.publish(
          generation_id: @generation_id,
          user: @user,
          status: status,
          session_id: @session.id,
          response: parsed,
        )
      end

      def publish_progress(stage, details = {})
        ::DiscourseWorkflows::Ai::ProgressPublisher.publish(
          generation_id: @generation_id,
          user: @user,
          status: "progress",
          stage: stage.to_s,
          message: I18n.t("discourse_workflows.ai.progress.#{stage}"),
          details: details,
        )
      end

      def publish_agent_stream_progress(partial, raw, type)
        case type
        when :thinking
          publish_tool_progress(partial, raw)
        when :structured_output
          publish_agent_progress_once(
            :drafting_response,
            I18n.t("discourse_workflows.ai.progress.drafting_response"),
          )
        when nil
          if partial.is_a?(String) && partial.present?
            publish_agent_progress_once(
              :writing_response,
              I18n.t("discourse_workflows.ai.progress.writing_response"),
            )
          end
        end
      end

      def publish_tool_progress(partial, raw)
        tool_label = tool_label_from_placeholder(raw.presence || partial)
        return if tool_label.blank?

        phase = raw.present? ? :using_tool : :tool_finished
        publish_agent_progress_once(
          "#{phase}:#{tool_label}",
          I18n.t("discourse_workflows.ai.progress.#{phase}", tool: tool_label),
          tool: tool_label,
        )
      end

      def tool_label_from_placeholder(value)
        first_line = value.to_s.lines.map(&:strip).find(&:present?)
        return if first_line.blank? || !first_line.start_with?("**") || !first_line.end_with?("**")

        first_line.delete_prefix("**").delete_suffix("**").gsub(/<[^>]*>/, "").strip
      end

      def publish_agent_progress_once(key, message, details = {})
        @published_agent_progress_keys ||= {}
        return if @published_agent_progress_keys[key]

        @published_agent_progress_keys[key] = true
        ::DiscourseWorkflows::Ai::ProgressPublisher.publish(
          generation_id: @generation_id,
          user: @user,
          status: "progress",
          stage: "agent_update",
          message: message,
          details: details.merge(key: key.to_s),
        )
      end

      def publish_error(message)
        @session&.update!(
          status: "error",
          latest_response: {
            "status" => "error",
            "message" => message,
          },
        )
        ::DiscourseWorkflows::Ai::ProgressPublisher.publish(
          generation_id: @generation_id,
          user: @user,
          status: "error",
          session_id: @session&.id,
          error: message,
        )
      end

      def json_safe(value)
        JSON.parse(JSON.generate(value))
      end
    end
  end
end
