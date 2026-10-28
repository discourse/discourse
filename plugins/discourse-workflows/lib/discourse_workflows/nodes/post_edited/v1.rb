# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostEdited
      class V1 < NodeType
        POST_SCOPE_OPTIONS = %w[first_post replies all_posts].freeze

        EDITOR_SCHEMA =
          Schema.document(
            "editor" => Schema.nullable_user("User who performed the edit, when available"),
          )

        BASE_OUTPUT_SCHEMA =
          Schema.merge(
            Schema::POST_SCHEMA,
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            Schema::USER_SCHEMA,
            Schema.document(
              "revision" => {
                "type" => %w[object null],
                "description" =>
                  "Revision created by the edit, null for edits within the grace period",
                "properties" => {
                  "number" => {
                    "type" => "integer",
                  },
                  "edit_reason" => {
                    "type" => %w[string null],
                  },
                  "changes" => {
                    "type" => "array",
                    "description" => "Names of the modified fields",
                    "items" => {
                      "type" => "string",
                    },
                  },
                  "previous_raw" => {
                    "type" => %w[string null],
                    "description" => "Raw before the edit, null when the raw did not change",
                  },
                },
              },
            ),
          )

        description(
          name: "trigger:post_edited",
          version: "1.0",
          defaults: {
            icon: "comment",
            color: "violet",
          },
          group: "discourse_triggers",
          event: :post_edited,
          output_contracts: [{ schema: Schema.merge(BASE_OUTPUT_SCHEMA, EDITOR_SCHEMA) }],
          properties: {
            post_scope: {
              type: :options,
              required: true,
              default: "first_post",
              options: POST_SCOPE_OPTIONS,
            },
            **TOPIC_SCOPE_FILTER_PROPERTIES,
            trust_levels: {
              type: :multi_options,
              required: false,
              options: trust_level_options,
            },
          },
        )

        deprecated(superseded_by: "2.0", changes: { "editor" => "actor" })

        def initialize(post, _topic_changed = nil, revisor = nil, *)
          super(parameters: {})
          @post = post
          @revisor = revisor
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == ::Post.types[:regular] &&
            !@revisor&.opts&.dig(:skip_workflows)
        end

        def output
          {
            post: serialize_post(@post, include_cooked: true),
            topic: serialize_topic_list_item(@post.topic),
            user: serialize_user(@post.user),
            **serialize_editor,
            revision: serialize_revision,
          }
        end

        def matches?(trigger_ctx)
          return false if !matches_post_scope?(trigger_ctx.get_node_parameter("post_scope"))
          return false if !matches_topic_filters?(@post.topic, trigger_ctx)

          matches_trust_level?(trigger_ctx.get_node_parameter("trust_levels"))
        end

        private

        def serialize_editor
          { editor: serialize_user(@revisor&.editor) }
        end

        def serialize_revision
          revision = @revisor&.post_revision
          return if revision.blank?

          {
            number: revision.number,
            edit_reason: @post.edit_reason,
            changes: revision.modifications.keys,
            previous_raw: revision.modifications.dig("raw", 0),
          }
        end

        def matches_post_scope?(post_scope)
          case post_scope
          when "all_posts"
            true
          when "replies"
            @post.post_number > 1
          else
            @post.post_number == 1
          end
        end

        def matches_trust_level?(trust_levels)
          trust_levels =
            Array.wrap(trust_levels).filter_map { |trust_level| trust_level.presence&.to_i }
          trust_levels.empty? || trust_levels.include?(@post.user&.trust_level)
        end
      end
    end
  end
end
