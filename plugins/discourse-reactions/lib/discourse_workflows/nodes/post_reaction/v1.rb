# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostReaction
        class V1 < DiscourseWorkflows::NodeType
          OPERATIONS = %w[add remove].freeze
          IF_EXISTS_OPTIONS = %w[keep replace].freeze
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
              "reaction" => {
                "type" => %w[string null],
              },
              "previous_reaction" => {
                "type" => %w[string null],
              },
              "changed" => {
                "type" => "boolean",
              },
            },
          }.freeze

          description(
            name: "action:post_reaction",
            version: "1.0",
            defaults: {
              icon: "far-face-smile",
              color: "yellow",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.discourse_reactions_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_reactions",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              operation: {
                type: :options,
                required: true,
                options: OPERATIONS,
                default: "add",
              },
              post_id: {
                type: :string,
                required: true,
              },
              reaction: {
                type: :emoji,
                required: true,
              },
              if_exists: {
                type: :options,
                required: true,
                options: IF_EXISTS_OPTIONS,
                default: "keep",
                display_options: {
                  show: {
                    operation: ["add"],
                  },
                },
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
            post = ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
            actor = exec_ctx.actor_from_parameter("actor_username", item_index)
            reaction = exec_ctx.get_node_parameter("reaction", item_index).to_s.delete(":")
            previous_reaction =
              ::DiscourseReactions::ReactionManager.reaction_value_for(user: actor, post:)

            add = exec_ctx.get_node_parameter("operation", item_index, default: "add") == "add"

            if add
              replace = exec_ctx.get_node_parameter("if_exists", item_index) == "replace"
              changed = previous_reaction != reaction && (previous_reaction.nil? || replace)
            else
              changed = previous_reaction == reaction
            end

            toggle_reaction(post, actor, reaction, item_index) if changed

            {
              post_id: post.id,
              username: actor.username,
              reaction: changed ? (reaction if add) : previous_reaction,
              previous_reaction:,
              changed:,
            }
          end

          def toggle_reaction(post, actor, reaction, item_index)
            ::DiscourseReactions::PostReaction::Toggle.call(
              params: {
                post_id: post.id,
                reaction:,
              },
              guardian: actor.guardian,
            ) do
              on_success {}
              on_failed_policy(:reaction_is_valid) do
                raise_node_error!(
                  I18n.t("discourse_reactions.errors.reaction_unavailable"),
                  description: reaction,
                  item_index:,
                )
              end
              on_failure do
                raise_node_error!(
                  I18n.t(
                    "discourse_reactions.discourse_workflows.post_reaction.cannot_react",
                    username: actor.username,
                  ),
                  item_index:,
                )
              end
            end
          end
        end
      end
    end
  end
end
