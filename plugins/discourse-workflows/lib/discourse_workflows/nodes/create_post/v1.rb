# frozen_string_literal: true

require_relative "../post_helper"

module DiscourseWorkflows
  module Nodes
    module CreatePost
      class V1 < NodeType
        include PostHelper
        description(
          name: "action:create_post",
          version: "1.0",
          defaults: {
            icon: "reply",
            color: "teal",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            topic_id: {
              type: :string,
              required: true,
            },
            raw: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
            },
            reply_to_post_number: {
              type: :integer,
              required: false,
            },
            author_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :user,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                "raw" => exec_ctx.get_node_parameter("raw", item_index),
                "reply_to_post_number" =>
                  exec_ctx.get_node_parameter("reply_to_post_number", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          post = create_workflow_post(exec_ctx, config, item_index)

          { post: post_data(post) }
        end

        def post_data(post)
          serialize_record(post, WebHookPostSerializer)
        end
      end
    end
  end
end
