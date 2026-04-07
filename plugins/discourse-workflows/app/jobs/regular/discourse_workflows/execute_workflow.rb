# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExecuteWorkflow < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::Workflow::Execute.call(
          params:
            args.slice(
              :workflow_id,
              :trigger_node_id,
              :trigger_data,
              :execution_mode,
              :error_depth,
              :user_id,
            ).compact,
        )
      end
    end
  end
end
