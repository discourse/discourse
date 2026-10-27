# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostHidden
      class V1 < NodeType
        include PostHidingTrigger

        description(
          PostHidingTrigger.description(
            name: "trigger:post_hidden",
            event: :post_hidden,
            icon: "far-eye-slash",
            color: "orange",
            output: {
              "flag_reason" => {
                "type" => %w[string null],
                "description" =>
                  "Flag reason behind the hide, such as spam or inappropriate. Null when no flag was involved",
              },
            },
          ),
        )

        def initialize(post, payload = {})
          super
          @flag_reason = ::ReviewableScore.types.key(payload[:post_action_type_id])&.to_s
        end

        def output
          super.merge(flag_reason: @flag_reason)
        end
      end
    end
  end
end
