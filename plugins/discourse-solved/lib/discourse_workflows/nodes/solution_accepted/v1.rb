# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SolutionAccepted
        class V1 < SolutionChanged::V1
          description(
            SolutionChanged::V1.description_for_change(
              "trigger:solution_accepted",
              "accepted",
            ).merge(defaults: { icon: "square-check", color: "green" }),
          )
        end
      end
    end
  end
end
