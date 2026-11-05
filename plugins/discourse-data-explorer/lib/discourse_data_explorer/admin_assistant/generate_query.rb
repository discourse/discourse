# frozen_string_literal: true

module DiscourseDataExplorer
  module AdminAssistant
    class GenerateQuery < DiscourseAi::Agents::Tools::Tool
      MAX_DESCRIPTION_LENGTH = 4000

      def self.name
        "generate_data_explorer_query"
      end

      def self.signature
        {
          name:,
          description:
            "Generate and test a Data Explorer query draft without saving it. Use create_data_explorer_query with the returned draft token to request approval to save the exact draft. For revisions, describe the complete revised request.",
          parameters: [
            {
              name: "description",
              type: "string",
              required: true,
              description: "The complete report or query requested by the administrator",
            },
          ],
        }
      end

      def self.help
        I18n.t("discourse_data_explorer.admin_assistant.generating")
      end

      def self.custom_system_message
        <<~TEXT
          When an administrator asks to create a Data Explorer query, first call generate_data_explorer_query with the complete request. If generation succeeds, call create_data_explorer_query with the exact returned draft token. Saving always requires explicit human approval.
        TEXT
      end

      def self.available_for_context?(context)
        Capability.visible?(context&.user)
      end

      def summary
        self.class.help
      end

      def details
        summary
      end

      def invoke
        if !context.user&.admin?
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.not_allowed"))
        end
        if Capability.status(user: context.user, phase: :generation) != :available
          return error_response(Capability.message(user: context.user, phase: :generation))
        end

        description = parameters[:description].to_s.strip
        if description.blank? || description.length > MAX_DESCRIPTION_LENGTH
          return error_response(I18n.t("discourse_data_explorer.admin_assistant.invalid_request"))
        end

        query =
          DiscourseDataExplorer::QueryGeneration.call(
            user: context.user,
            ai_description: description,
          )
        query.merge(status: "success", draft_token: QueryDraft.sign(query, user: context.user))
      rescue DiscourseDataExplorer::QueryGeneration::Error, Discourse::InvalidParameters
        error_response(I18n.t("discourse_data_explorer.admin_assistant.generation_failed"))
      end
    end
  end
end
