# frozen_string_literal: true

module DiscourseWorkflows
  module AdminAssistant
    class GenerateWorkflow < DiscourseAi::Agents::Tools::Tool
      def self.name
        "generate_workflow"
      end

      def self.signature
        {
          name:,
          description:
            "Generate and validate an unpublished workflow draft without saving it. Do not include passwords, tokens, API keys, credentials, or other secrets. If clarification is needed, ask the administrator the returned questions and retry with their answers included. Use create_workflow with the returned draft token to request approval to save the exact draft.",
          parameters: [
            {
              name: "description",
              type: "string",
              required: true,
              description: "The complete workflow requested by the administrator, without secrets",
            },
          ],
        }
      end

      def self.help
        I18n.t("discourse_workflows.admin_assistant.generating")
      end

      def self.custom_system_message
        <<~TEXT
          When an administrator asks to create a workflow, first call generate_workflow with the complete request and no secrets. If it returns needs_clarification, ask the returned questions and call generate_workflow again with the original request and answers. If generation succeeds, call create_workflow with the exact returned draft token. Saving always requires explicit human approval. Never claim that a workflow is active or execute it; newly saved workflows are unpublished.
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
        if !Capability.authorized?(context.user)
          return error_response(I18n.t("discourse_workflows.admin_assistant.not_allowed"))
        end
        if Capability.status(user: context.user, phase: :generation) != :available
          return error_response(Capability.message(user: context.user, phase: :generation))
        end

        description = parameters[:description].to_s.strip
        if description.blank? || WorkflowDraft.contains_secret_text?(description) ||
             description.length > SiteSetting.discourse_workflows_ai_authoring_max_prompt_length
          return error_response(I18n.t("discourse_workflows.admin_assistant.invalid_request"))
        end

        session = create_session(description)
        Jobs::DiscourseWorkflows::AuthorWithAi.new.execute(
          session_id: session.id,
          user_id: context.user.id,
          generation_id: SecureRandom.hex,
        )
        session.reload
        return clarification_response(session) if session.status == "needs_clarification"
        return generation_error unless session.status == "proposal_ready"

        proposal = session.proposed_patch.symbolize_keys
        operations = Array.wrap(proposal[:operations])
        public_text = [proposal[:title], proposal[:workflow_name], proposal[:summary]].compact.join(
          "\n",
        )
        if WorkflowDraft.contains_secret?(operations) ||
             WorkflowDraft.contains_secret?(proposal[:script_validations]) ||
             WorkflowDraft.contains_secret_text?(public_text)
          return generation_error
        end

        name =
          (proposal[:workflow_name].presence || proposal[:title].presence || description).truncate(
            100,
          )
        validation = validate_draft(name, operations)
        return generation_error unless validation[:valid]

        draft_attributes = {
          name:,
          operations:,
          script_validations: proposal[:script_validations],
        }.compact
        draft_token = WorkflowDraft.sign(draft_attributes, user: context.user)
        {
          status: "success",
          name:,
          summary: proposal[:summary].to_s,
          script_validations: proposal[:script_validations],
          draft_token:,
        }.compact
      rescue ActiveRecord::ActiveRecordError, Discourse::InvalidParameters
        generation_error
      ensure
        session&.destroy!
      end

      private

      def clarification_response(session)
        response = session.latest_response.symbolize_keys
        questions = Array.wrap(response[:questions])
        return generation_error if questions.blank? || WorkflowDraft.contains_secret?(questions)

        message = response[:message].to_s
        if message.blank? || WorkflowDraft.contains_secret_text?(message)
          message = I18n.t("discourse_workflows.admin_assistant.clarification_required")
        end
        { status: "needs_clarification", message:, questions: }
      end

      def create_session(description)
        DiscourseWorkflows::AiAuthoringSession.create!(
          user: context.user,
          status: "drafting",
          latest_request: description,
          latest_response: {
          },
          proposed_patch: {
          },
          messages: [
            {
              "type" => "user",
              "content" =>
                JSON.generate(
                  mode: "create",
                  message: description,
                  secret_handling: "never include secrets",
                ),
            },
          ],
        )
      end

      def generation_error
        error_response(I18n.t("discourse_workflows.admin_assistant.generation_failed"))
      end

      def validate_draft(name, operations)
        DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch.new(
          { workflow_name: name, operations: },
          bot_user: Discourse.system_user,
          llm: nil,
          context: DiscourseAi::Agents::BotContext.new(messages: [], user: context.user),
        ).invoke
      end
    end
  end
end
