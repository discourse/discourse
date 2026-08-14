# frozen_string_literal: true

module Chat
  module Workflows
    module Approval
      class ResumeInteraction
        include Service::Base

        params do
          attribute :interaction_id, :integer

          validates :interaction_id, presence: true
        end

        policy :workflows_enabled

        model :interaction
        model :resolved_interaction
        model :claimed_resume_request
        step :resume_execution

        private

        def workflows_enabled
          SiteSetting.enable_discourse_workflows
        end

        def fetch_interaction(params:)
          Chat::MessageInteraction.includes(:user, message: :chat_channel).find_by(
            id: params.interaction_id,
          )
        end

        def fetch_resolved_interaction(interaction:)
          Chat::Workflows::Approval::InteractionResolver.call(interaction)
        end

        def fetch_claimed_resume_request(resolved_interaction:)
          resolved_interaction.resume_request.claim
        end

        def resume_execution(claimed_resume_request:, resolved_interaction:)
          claimed_resume_request.resume!(
            resolved_interaction.response_items,
            user: resolved_interaction.user,
          )
        end
      end
    end
  end
end
