# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Manual
      class V1 < NodeType
        def self.identifier
          "trigger:manual"
        end

        def self.icon
          "arrow-pointer"
        end

        def self.manually_triggerable?
          true
        end

        def self.provides_current_user?
          true
        end

        def initialize(*)
          super(configuration: {})
        end

        def output
          {}
        end
      end
    end
  end
end
