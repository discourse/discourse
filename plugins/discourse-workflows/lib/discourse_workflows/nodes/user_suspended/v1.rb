# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSuspended
      class V1 < UserModerationChanged::V1
        description(
          UserModerationChanged::V1.description_for_change(
            "suspended",
            icon: "ban",
            output_schema: UserModerationChanged::V1::PENALTY_OUTPUT_SCHEMA,
          ),
        )

        def output
          super.except(:change)
        end
      end
    end
  end
end
