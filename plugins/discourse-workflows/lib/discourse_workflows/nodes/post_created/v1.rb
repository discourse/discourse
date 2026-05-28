# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostCreated
      class V1 < NodeType
        description(
          name: "trigger:post_created",
          version: "1.0",
          defaults: {
            icon: "comment",
            color: "indigo",
          },
          group: "discourse_triggers",
          events: [:post_created],
          properties: {
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
          },
        )

        def initialize(post, opts = nil, *)
          super(parameters: {})
          @post = post
          @opts = opts
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == Post.types[:regular] &&
            !@opts&.dig(:skip_workflows)
        end

        def output
          { post: post_data(@post), topic: topic_data(@post.topic) }
        end

        def matches?(trigger_ctx)
          topic = @post.topic

          matches_category?(topic, trigger_ctx.get_node_parameter("category_id")) &&
            matches_tags?(topic, normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def post_data(post)
          serialize_record(post, WebHookPostSerializer)
        end

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def matches_category?(topic, category_id)
          category_id.blank? || topic.category_id == category_id.to_i
        end

        def matches_tags?(topic, tag_names)
          tag_names.empty? || (topic_tag_names(topic) & tag_names).any?
        end

        def topic_tag_names(topic)
          @topic_tag_names ||= topic.tags.pluck(:name)
        end
      end
    end
  end
end
