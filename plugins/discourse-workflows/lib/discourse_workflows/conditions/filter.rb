# frozen_string_literal: true

module DiscourseWorkflows
  module Conditions
    class Filter < IfCondition
      def self.identifier
        "condition:filter"
      end
    end
  end
end
