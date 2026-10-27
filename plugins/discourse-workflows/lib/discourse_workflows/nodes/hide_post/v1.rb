# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HidePost
      class V1 < NodeType
        include PostHiding

        HIDDEN = true
        FLAG_REASONS = %w[notify_moderators inappropriate off_topic spam].freeze

        description(
          PostHiding.description(
            name: "action:hide_post",
            icon: "far-eye-slash",
            properties: {
              flag_reason: {
                type: :options,
                required: true,
                default: "notify_moderators",
                options: FLAG_REASONS,
                ui: {
                  expression: true,
                },
              },
            },
          ),
        )

        private

        # Hidden the way flags hide a post: after a first hide, its author can unhide it by editing it.
        def perform_change(exec_ctx, post, actor, item_index)
          flag_reason =
            exec_ctx.get_node_parameter(
              "flag_reason",
              item_index,
              default: "notify_moderators",
            ).to_s
          if FLAG_REASONS.exclude?(flag_reason)
            hiding_error!("unknown_flag_reason", item_index, flag_reason:)
          end

          post.hide!(PostActionType.types[flag_reason.to_sym], acting_user: actor)
        end
      end
    end
  end
end
