# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Manual
      class V1 < NodeType
        description(
          name: "trigger:manual",
          version: "1.0",
          defaults: {
            icon: "arrow-pointer",
          },
          capabilities: {
            manually_triggerable: true,
            provides_current_user: true,
          },
        )

        def initialize(*)
          super(parameters: {})
        end

        def output
          {}
        end
      end
    end
  end
end
