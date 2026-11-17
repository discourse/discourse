# frozen_string_literal: true

module DiscourseDataExplorer
  module AdminAssistant
    class CreateQuery < DiscourseAi::Agents::Tools::Tool
      def self.name
        "create_data_explorer_query"
      end

      def self.signature
        {
          name:,
          description:
            "Request human approval to save an exact generated Data Explorer query draft. Never invent, alter, or reuse the draft token.",
          parameters: [
            {
              name: "draft_token",
              type: "string",
              required: true,
              description: "The draft token returned by generate_data_explorer_query",
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
        I18n.t("discourse_data_explorer.admin_assistant.create_summary")
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
        return I18n.t("discourse_data_explorer.admin_assistant.invalid_draft") unless draft

        [draft[:name], draft[:description], draft[:sql]].map do |text|
            text.to_s.lines.map { |line| "    #{line}" }.join
          end
          .join("\n\n")
      end

      def validation_error
        if !context.user&.admin?
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.not_allowed"))
        end
        if Capability.status(user: context.user, phase: execution_phase) != :available
          return error_response(Capability.message(user: context.user, phase: execution_phase))
        end
        if !draft
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.invalid_draft"))
        end
        if draft[:sql].blank? || draft[:name].blank?
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.incomplete_draft"))
        end

        requester = User.find_by(id: draft[:user_id], admin: true)
        if requester.blank?
          return(
            error_response(I18n.t("discourse_data_explorer.admin_assistant.requester_not_admin"))
          )
        end
        if context.reviewable_id.blank? && draft[:user_id] != context.user.id
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.not_allowed"))
        end
        parameters[:requester_id] = draft[:user_id] if context.reviewable_id.blank?

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
          unless QueryDraft.claim(parameters[:draft_token], reviewable_id: reviewable.id)
            return error_response(I18n.t("discourse_data_explorer.admin_assistant.draft_used"))
          end

          begin
            query = nil
            DiscourseDataExplorer::Query.transaction do
              query =
                DiscourseDataExplorer::QueryCreator.create(
                  query_params: draft.slice(:name, :description, :sql),
                  group_ids: [],
                  user: context.user,
                )
              QueryDraft.complete_after_transaction(
                parameters[:draft_token],
                reviewable_id: reviewable.id,
                resource_id: query.id,
              )
            end
            { status: "success", query_id: query.id, url: query_url(query) }
          rescue => error
            QueryDraft.release(parameters[:draft_token], reviewable_id: reviewable.id)
            raise error
          end
        end
      rescue ActiveRecord::ActiveRecordError, Discourse::InvalidParameters
        error_response(I18n.t("discourse_data_explorer.admin_assistant.creation_failed"))
      end

      private

      def approval_required
        error_response(I18n.t("discourse_data_explorer.admin_assistant.approval_required"))
      end

      def draft
        @draft ||= QueryDraft.read_with_compatibility(parameters[:draft_token])
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

      def query_url(query)
        "#{Discourse.base_url}/admin/plugins/discourse-data-explorer/queries/#{query.id}"
      end
    end
  end
end
