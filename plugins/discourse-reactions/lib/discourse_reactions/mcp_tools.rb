# frozen_string_literal: true

module DiscourseReactions
  module McpTools
    class SetReaction
      REQUIRED_SCOPES = %w[discourse-reactions:write].freeze
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          post_id: DiscourseMcp::OutputSchema::INTEGER,
          reaction: DiscourseMcp::OutputSchema::STRING,
        )

      def self.call(arguments:, request_context:)
        reaction = arguments.fetch("reaction")

        DiscourseReactions::PostReaction::Toggle.call(
          params: {
            post_id: arguments.fetch("post_id"),
            reaction:,
          },
          guardian: request_context.guardian,
        ) do |result|
          on_success do |post:|
            DiscourseMcp::ToolHelpers.text_and_structured(post_id: post.id, reaction:)
          end
          on_model_not_found(:post) { raise DiscourseMcp::ToolError, "Post not found" }
          on_failed_policy(:can_see_post) { raise DiscourseMcp::ToolError, "Post not found" }
          on_failed_policy(:reaction_is_valid) do
            raise DiscourseMcp::ToolError, I18n.t("discourse_reactions.errors.reaction_unavailable")
          end
          on_exceptions(Discourse::InvalidAccess) { |exception| raise exception }
          on_failure { raise DiscourseMcp::ToolError, result.inspect_steps }
        end
      end
    end
  end
end
