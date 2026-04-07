# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExecuteSecondsSchedule < ::Jobs::Base
      def execute(args)
        workflow_id = args[:workflow_id]
        node_id = args[:trigger_node_id]
        rule_index = args[:rule_index]
        token = args[:token]

        workflow = ::DiscourseWorkflows::Workflow.find_by(id: workflow_id)
        return if workflow.nil? || !workflow.enabled?
        unless ::DiscourseWorkflows::ScheduleRule.seconds_token_valid?(
                 workflow,
                 node_id,
                 rule_index,
                 token,
               )
          return
        end

        node = workflow.parsed_nodes.find { |n| n["id"] == node_id }
        return if node.nil?

        rules =
          ::DiscourseWorkflows::ScheduleRule.rules_from_configuration(node["configuration"] || {})
        rule = rules[rule_index]
        return if rule.nil? || !::DiscourseWorkflows::ScheduleRule.seconds_rule?(rule)

        now = Time.current.utc
        ::DiscourseWorkflows::ScheduleRule.mark_seconds_triggered!(
          workflow,
          node_id,
          rule_index,
          now,
        )

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          workflow_id: workflow.id,
          trigger_node_id: node_id,
          trigger_data: ::DiscourseWorkflows::Nodes::Schedule::V1.new.output,
        )

        interval = ::DiscourseWorkflows::ScheduleRule.seconds_interval(rule)
        Jobs.enqueue_in(
          interval.seconds,
          Jobs::DiscourseWorkflows::ExecuteSecondsSchedule,
          workflow_id: workflow_id,
          trigger_node_id: node_id,
          rule_index: rule_index,
          token: token,
        )
      end
    end
  end
end
