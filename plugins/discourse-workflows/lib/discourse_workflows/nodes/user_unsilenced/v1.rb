# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserUnsilenced
      class V1 < UserModerationChanged::V1
        description(
          UserModerationChanged::V1.description_for_change(
            "unsilenced",
            icon: "microphone",
            output_schema: UserModerationChanged::V1::LIFT_OUTPUT_SCHEMA,
          ),
        )

        def output
          super.slice(:user, :actor)
        end
      end
    end
  end
end
