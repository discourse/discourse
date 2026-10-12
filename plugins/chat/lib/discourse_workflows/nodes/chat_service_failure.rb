# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatServiceFailure
        # `on_failure` gets no step context, and `inspect_steps` is developer output,
        # so name the failed step for the execution log instead.
        def self.failed_step_name(result)
          Service::StepsInspector
            .new(result)
            .steps
            .detect(&:failure?)
            &.result_key
            &.delete_prefix("result.") || "unknown"
        end
      end
    end
  end
end
