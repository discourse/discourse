# frozen_string_literal: true

module DiscourseWorkflows
  module Conditions
    module Filter
      class V1 < IfCondition::V1
        def self.identifier
          "condition:filter"
        end
      end
    end
  end
end
