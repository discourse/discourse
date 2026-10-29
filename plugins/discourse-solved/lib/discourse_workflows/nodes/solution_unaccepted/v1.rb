# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SolutionUnaccepted
        class V1 < SolutionChanged::V1
          description(
            SolutionChanged::V1.description_for_change(
              "trigger:solution_unaccepted",
              "removed",
            ).merge(defaults: { icon: "far-square", color: "green" }),
          )
        end
      end
    end
  end
end
