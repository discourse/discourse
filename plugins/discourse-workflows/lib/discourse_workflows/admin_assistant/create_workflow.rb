# frozen_string_literal: true

module DiscourseWorkflows
  module AdminAssistant
    class CreateWorkflow < DiscourseAi::Agents::Tools::Tool
      PREVIEW_KIND = "discourse_admin_assistant_workflow_preview_v1"
      # Keys the preview needs to rebuild the graph, so they are never shortened.
      PREVIEW_GRAPH_KEYS = %w[
        op
        client_id
        node_id
        from
        to
        from_node_id
        to_node_id
        connection_type
        id
        type
        $ref
      ].freeze
      SHORTENED_VALUE_LENGTHS = [500, 160, 60].freeze

      def self.name
        "create_workflow"
      end

      def self.signature
        {
          name:,
          description:
            "Request human approval to save an exact validated workflow draft as unpublished. Never invent, alter, or reuse the draft token.",
          parameters: [
            {
              name: "draft_token",
              type: "string",
              required: true,
              description: "The draft token returned by generate_workflow",
            },
          ],
        }
      end

      def self.requires_approval?
        true
      end

      def self.mandatory_approval?
        true
      end

      def self.attribute_to_approver?
        true
      end

      def self.help
        I18n.t("discourse_workflows.admin_assistant.create_summary")
      end

      def self.available_for_context?(context)
        Capability.visible?(context&.user)
      end

      def summary
        self.class.help
      end

      def approval_parameters
        []
      end

      def details
        return I18n.t("discourse_workflows.admin_assistant.invalid_draft") unless draft
        if WorkflowDraft.contains_secret?(configuration)
          return I18n.t("discourse_workflows.admin_assistant.secret_draft")
        end

        preview_details(configuration)
      end

      # Large drafts do not fit in a chat message, so the preview keeps the full
      # graph and shortens long setting values, then drops settings entirely.
      def compact_approval_details(max_length:)
        return super if !draft || WorkflowDraft.contains_secret?(configuration)

        candidates =
          Enumerator.new do |yielder|
            yielder << preview_details(configuration, pretty: false)
            SHORTENED_VALUE_LENGTHS.each do |length|
              yielder << preview_details(
                shorten_values(configuration, length),
                pretty: false,
                shortened: true,
              )
            end
            yielder << preview_details(
              shorten_values(without_settings(configuration), SHORTENED_VALUE_LENGTHS.last),
              pretty: false,
              shortened: true,
            )
          end

        candidates.find { |candidate| candidate.length <= max_length } || super
      end

      def validation_error
        if !Capability.authorized?(context.user)
          return error_response(I18n.t("discourse_workflows.admin_assistant.not_allowed"))
        end
        if Capability.status(user: context.user, phase: execution_phase) != :available
          return error_response(Capability.message(user: context.user, phase: execution_phase))
        end
        return error_response(I18n.t("discourse_workflows.admin_assistant.invalid_draft")) if !draft
        if draft[:name].blank? || !draft[:operations].is_a?(Array) || draft[:operations].blank?
          return error_response(I18n.t("discourse_workflows.admin_assistant.incomplete_draft"))
        end
        if WorkflowDraft.contains_secret?(configuration)
          return error_response(I18n.t("discourse_workflows.admin_assistant.secret_draft"))
        end

        requester = User.find_by(id: draft[:user_id], admin: true)
        if !requester || !requester.guardian.can_manage_workflows?
          return error_response(I18n.t("discourse_workflows.admin_assistant.requester_not_admin"))
        end
        if context.reviewable_id.blank? && draft[:user_id] != context.user.id
          return error_response(I18n.t("discourse_workflows.admin_assistant.not_allowed"))
        end
        parameters[:requester_id] = draft[:user_id] if context.reviewable_id.blank?

        validation = validate_draft
        if !validation[:valid]
          return error_response(I18n.t("discourse_workflows.admin_assistant.invalid_graph"))
        end

        nil
      end

      def invoke
        validation_failure = validation_error
        return validation_failure if validation_failure
        return approval_required if context.reviewable_id.blank?

        reviewable = matching_reviewable
        return approval_required if reviewable.blank?

        reviewable.with_lock do
          return approval_required if !reviewable.pending?
          unless WorkflowDraft.claim(parameters[:draft_token], reviewable_id: reviewable.id)
            return error_response(I18n.t("discourse_workflows.admin_assistant.draft_used"))
          end

          begin
            workflow = create_unpublished_workflow!
            WorkflowDraft.complete_after_transaction(
              parameters[:draft_token],
              reviewable_id: reviewable.id,
              resource_id: workflow.id,
            )
            { status: "success", workflow_id: workflow.id, url: workflow_url(workflow) }
          rescue => error
            WorkflowDraft.release(parameters[:draft_token], reviewable_id: reviewable.id)
            raise error
          end
        end
      rescue ActiveRecord::ActiveRecordError, Discourse::InvalidParameters
        error_response(I18n.t("discourse_workflows.admin_assistant.creation_failed"))
      end

      private

      def approval_required
        error_response(I18n.t("discourse_workflows.admin_assistant.approval_required"))
      end

      def configuration
        draft.slice(:name, :operations, :script_validations)
      end

      def preview_details(preview_configuration, pretty: true, shortened: false)
        payload = { kind: PREVIEW_KIND, configuration: preview_configuration }
        payload[:shortened] = true if shortened
        preview = pretty ? JSON.pretty_generate(payload) : JSON.generate(payload)
        longest_run = preview.scan(/`+/).map(&:length).max.to_i
        fence = "`" * [3, longest_run + 1].max
        "#{fence}admin-assistant-workflow\n#{preview}\n#{fence}\n"
      end

      def shorten_values(value, length, key = nil)
        case value
        when Hash
          value.to_h do |nested_key, nested_value|
            [nested_key, shorten_values(nested_value, length, nested_key)]
          end
        when Array
          value.map { |nested_value| shorten_values(nested_value, length, key) }
        when String
          PREVIEW_GRAPH_KEYS.include?(key.to_s) ? value : value.truncate(length)
        else
          value
        end
      end

      def without_settings(preview_configuration)
        operations =
          Array
            .wrap(preview_configuration[:operations])
            .map do |operation|
              next operation if !operation.is_a?(Hash)

              case operation["op"]
              when "add_node"
                node = operation["node"]
                if node.is_a?(Hash)
                  operation.merge("node" => node.slice("id", "name", "type"))
                else
                  operation
                end
              when "create_ai_agent"
                agent = operation["agent"]
                agent.is_a?(Hash) ? operation.merge("agent" => agent.slice("name")) : operation
              when "update_node_parameters"
                operation.except("parameters")
              else
                operation
              end
            end

        preview_configuration.merge(operations:)
      end

      def create_unpublished_workflow!
        workflow = nil
        DiscourseWorkflows::Workflow.transaction do
          result =
            DiscourseWorkflows::Workflow::Create.call(
              params: {
                name: draft[:name],
                nodes: [],
                connections: {
                },
              },
              guardian: context.user.guardian,
            )
          raise Discourse::InvalidParameters if !result.success?

          workflow = result[:workflow]
          patch =
            DiscourseWorkflows::Workflow::Action::ApplyPatch.call(
              workflow:,
              operations: draft[:operations],
              persist: true,
              user: context.user,
            )
          raise Discourse::InvalidParameters if !patch[:valid] || workflow.reload.published?
        end
        raise Discourse::InvalidParameters if !workflow&.persisted?

        workflow
      end

      def draft
        @draft ||= WorkflowDraft.read_with_compatibility(parameters[:draft_token])
      end

      def execution_phase
        context.reviewable_id.present? ? :approval : :request
      end

      def matching_reviewable
        item = ReviewableAiToolAction.find_by(id: context.reviewable_id)
        return if !item || item.target&.tool_name != self.class.name
        return if item.target.tool_parameters["draft_token"] != parameters[:draft_token]
        return if item.target.tool_parameters["requester_id"].to_i != draft[:user_id]

        item
      end

      def validate_draft
        DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch.new(
          { workflow_name: draft[:name], operations: draft[:operations] },
          bot_user: Discourse.system_user,
          llm: nil,
          context: DiscourseAi::Agents::BotContext.new(messages: [], user: context.user),
        ).invoke
      end

      def workflow_url(workflow)
        "#{Discourse.base_url}/admin/plugins/discourse-workflows/workflows/#{workflow.id}"
      end
    end
  end
end
