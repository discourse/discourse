# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostHidingTrigger
      include PostModerationTrigger

      HIDDEN_REASON_SCHEMA =
        Schema.document(
          "hidden_reason" => {
            "type" => %w[string null],
            "enum" => [*::Post.hidden_reasons.keys.map(&:to_s), nil],
            "description" => "Why the post is hidden, or was hidden before it became visible again",
          },
        )

      def self.description(name:, event:, icon:, color:, output: {})
        PostModerationTrigger.description(
          name:,
          event:,
          icon:,
          color:,
          schema:
            Schema.merge(
              PostLifecycle::V2::OUTPUT_CONTRACTS.first[:schema],
              HIDDEN_REASON_SCHEMA,
              Schema.document(output),
            ),
        )
      end

      def output
        super.merge(hidden_reason: ::Post.hidden_reasons.key(@post.hidden_reason_id)&.to_s)
      end
    end
  end
end
