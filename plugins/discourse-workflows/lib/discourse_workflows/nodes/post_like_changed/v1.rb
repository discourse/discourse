# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLikeChanged
      class V1 < NodeType
        CHANGES = { like_created: "liked", like_destroyed: "unliked" }.freeze

        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::POST_SCHEMA,
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            Schema::USER_SCHEMA,
            Schema.document("change" => { "type" => "string", "enum" => CHANGES.values }),
          ).freeze

        description(
          name: "trigger:post_like_changed",
          version: "1.0",
          defaults: {
            icon: "heart",
            color: "red",
          },
          group: "discourse_triggers",
          event: CHANGES.keys,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            changes: {
              type: :multi_options,
              required: false,
              default: [],
              options: CHANGES.values,
            },
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
          },
        )

        def self.from_event(event_name, post_action, *)
          new(event_name, post_action)
        end

        def initialize(event_name, post_action)
          super(parameters: {})
          @change = CHANGES[event_name]
          @post = post_action.post
          @user = post_action.user
        end

        def valid?
          @change.present? && @post&.topic.present? && @user.present?
        end

        def user_id
          @user.id
        end

        def output
          {
            change: @change,
            post: serialize_post(@post),
            topic: topic_data(@post.topic),
            user: serialize_user(@user),
          }
        end

        def matches?(trigger_ctx)
          matches_changes?(trigger_ctx, @change) && matches_topic_filters?(@post.topic, trigger_ctx)
        end
      end
    end
  end
end
