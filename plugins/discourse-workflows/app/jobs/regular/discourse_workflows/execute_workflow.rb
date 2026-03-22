# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExecuteWorkflow < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::Workflow::Execute.call(
          params: {
            trigger_node_id: args[:trigger_node_id],
            trigger_data: args[:trigger_data],
          },
        )
      end
    end
  end
end
