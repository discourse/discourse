# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableApproved
      class V1 < ReviewableStatusChanged::V1
        description(
          ReviewableStatusChanged::V1.description_for_status("approved").merge(
            defaults: {
              icon: "user-check",
              color: "green",
            },
          ),
        )

        def output
          { reviewable: serialize_reviewable(@reviewable), actor: serialize_user(@actor) }
        end
      end
    end
  end
end
