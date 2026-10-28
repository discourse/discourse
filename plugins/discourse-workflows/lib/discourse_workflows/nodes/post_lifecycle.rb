# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLifecycle
      I18N_SCOPE = "post_lifecycle"
      PROPERTIES = {
        **NodeType::TOPIC_TYPE_FILTER_PROPERTIES,
        **NodeType::TOPIC_SCOPE_FILTER_PROPERTIES,
      }.freeze

      OUTPUT_CONTRACTS = [
        {
          schema:
            Schema.merge(
              Schema::POST_SCHEMA,
              Schema::TOPIC_LIST_ITEM_SCHEMA,
              Schema::USER_SCHEMA,
              Schema::ACTOR_SCHEMA,
            ),
        },
      ].freeze

      module V2
        OUTPUT_CONTRACTS = [
          {
            schema:
              Schema.merge(
                PostLifecycle::OUTPUT_CONTRACTS.first[:schema],
                Schema::POST_AUTHOR_SCHEMA,
              ),
          },
        ].freeze

        private

        def subject_user
          @post.user
        end
      end

      def initialize(post, opts = nil, actor = nil, *)
        super(parameters: {})
        @post = post
        @opts = opts
        @actor = actor
      end

      def valid?
        @post.present? && @post.post_type == ::Post.types[:regular] &&
          !@opts&.dig(:skip_workflows) && topic.present?
      end

      def output
        {
          post: serialize_post(@post),
          topic: serialize_topic_list_item(topic),
          user: serialize_user(subject_user),
          actor: serialize_user(@actor),
        }
      end

      def matches?(trigger_ctx)
        matches_topic_type?(topic, trigger_ctx.get_node_parameter("topic_type")) &&
          matches_topic_filters?(topic, trigger_ctx)
      end

      private

      def subject_user
        @actor
      end

      def topic
        return @topic if defined?(@topic)

        @topic =
          @post.association(:topic).target || ::Topic.with_deleted.find_by(id: @post.topic_id)
      end
    end
  end
end
