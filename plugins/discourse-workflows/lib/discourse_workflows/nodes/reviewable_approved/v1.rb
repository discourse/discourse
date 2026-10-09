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

        def self.load_options_context(context)
          case context.method_name
          when "reviewable_types"
            reviewable_type_options.select { |option| context.matches_filter?(option[:name]) }
          end
        end

        def output
          { reviewable: reviewable_data(@reviewable) }
        end
      end
    end
  end
end
