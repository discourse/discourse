# frozen_string_literal: true

module Chat
  module Workflows
    module Approval
      class Resume
        include Service::Base

        policy :workflows_enabled

        params do
          attribute :action_id, :string
          attribute :channel_id, :integer

          validates :action_id, presence: true
          validates :channel_id, presence: true
        end

        model :resume_request
        model :claimed_resume_request
        step :resume_execution

        private

        def workflows_enabled
          SiteSetting.enable_discourse_workflows
        end

        def fetch_resume_request(params:)
          ::DiscourseWorkflows::InteractiveResume.from_action_id(
            params.action_id,
            expected_node_type: "action:chat_approval",
            allowed_actions: %w[approve deny],
          )
        end

        def fetch_claimed_resume_request(resume_request:)
          resume_request.claim
        end

        def resume_execution(claimed_resume_request:, params:)
          response_items = [
            {
              "json" => {
                "approved" => claimed_resume_request.action == "approve",
                "channel_id" => params.channel_id,
              },
            },
          ]
          claimed_resume_request.resume!(response_items)
        end
      end
    end
  end
end
