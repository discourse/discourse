# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLike
      class V1 < NodeType
        OPERATIONS = %w[like unlike].freeze
        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "post_id" => {
              "type" => "integer",
            },
            "username" => {
              "type" => "string",
            },
            "changed" => {
              "type" => "boolean",
            },
          },
        }.freeze

        description(
          name: "action:post_like",
          version: "1.0",
          defaults: {
            icon: "heart",
            color: "red",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "like",
            },
            post_id: {
              type: :string,
              required: true,
            },
            **actor_property(allow_anonymous: false),
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              wrap(process(exec_ctx, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, item_index)
          like = exec_ctx.get_node_parameter("operation", item_index) != "unlike"
          post = ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          liked =
            ::PostAction.exists?(
              post:,
              user: actor,
              post_action_type_id: ::PostActionType::LIKE_POST_ACTION_ID,
            )
          changed = like != liked

          if changed
            result =
              if like
                ::PostActionCreator.like(actor, post)
              else
                ::PostActionDestroyer.destroy(actor, post, :like)
              end
            raise_node_error!(result.errors.full_messages.join(", "), item_index:) if result.failed?
          end

          { post_id: post.id, username: actor.username, changed: }
        end
      end
    end
  end
end
