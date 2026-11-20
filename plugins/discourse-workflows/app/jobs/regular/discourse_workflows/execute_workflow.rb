# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExecuteWorkflow < ::Jobs::Base
      def execute(args)
        feedback = args[:post_button_feedback]&.symbolize_keys
        job_id = jid || (SecureRandom.hex(12) if feedback)
        if feedback
          return if ::DiscourseWorkflows::Execution.exists?(job_id:)

          feedback = feedback.merge(user_id: args[:user_id])
          ::DiscourseWorkflows::PostButtonFeedback.remember(job_id, feedback)
        end

        result =
          ::DiscourseWorkflows::Workflow::Execute.call(
            params:
              args
                .slice(
                  :workflow_id,
                  :workflow_version_id,
                  :trigger_node_id,
                  :trigger_data,
                  :execution_mode,
                  :user_id,
                )
                .merge(job_id:)
                .compact,
          )
        if feedback && !result[:execution] && !::DiscourseWorkflows::Execution.exists?(job_id:)
          ::DiscourseWorkflows::PostButtonFeedback.finish(job_id, "error")
        end
      end
    end
  end
end
