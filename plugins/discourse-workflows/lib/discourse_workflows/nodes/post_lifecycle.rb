# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLifecycle
      I18N_SCOPE = "post_lifecycle"
      PROPERTIES = {
        topic_type: {
          type: :options,
          required: true,
          default: "topics",
          options: NodeType::TOPIC_TYPE_OPTIONS,
        },
        category_ids: {
          type: :array,
          required: false,
          ui: {
            control: :category,
            multiple: true,
          },
        },
        include_subcategories: {
          type: :boolean,
          required: false,
          default: true,
          ui: {
            control: :checkbox,
          },
          display_options: {
            show: {
              category_ids: [{ condition: { exists: true } }],
            },
          },
        },
        tag_names: {
          type: :string,
          required: false,
          ui: {
            control: :tags,
          },
        },
      }.freeze

      OUTPUT_CONTRACTS = [
        {
          schema:
            Schema.merge(Schema::POST_SCHEMA, Schema::TOPIC_LIST_ITEM_SCHEMA, Schema::USER_SCHEMA),
        },
      ].freeze

      def initialize(post, opts = nil, user = nil, *)
        super(parameters: {})
        @post = post
        @opts = opts
        @user = user
      end

      def valid?
        @post.present? && @post.post_type == ::Post.types[:regular] &&
          !@opts&.dig(:skip_workflows) && topic.present?
      end

      def output
        { post: serialize_post(@post), topic: topic_data(topic), user: serialize_user(@user) }
      end

      def matches?(trigger_ctx)
        matches_topic_type?(topic, trigger_ctx.get_node_parameter("topic_type", "topics")) &&
          matches_category_ids?(
            topic.category_id,
            category_ids_parameter(trigger_ctx),
            include_subcategories: trigger_ctx.get_node_parameter("include_subcategories", true),
          ) &&
          matches_tags?(topic, normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
      end

      private

      def topic
        return @topic if defined?(@topic)

        @topic =
          @post.association(:topic).target || ::Topic.with_deleted.find_by(id: @post.topic_id)
      end
    end
  end
end
