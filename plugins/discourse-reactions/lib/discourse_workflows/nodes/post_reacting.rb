# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      # Add reaction and Remove reaction toggle the actor's reaction like the reaction picker, so they follow
      # its rules. Like liking, seeing the post is enough to be told nothing changed.
      module PostReacting
        include PostChangeAction

        def self.description(name:, icon:, changed:, properties: {})
          PostChangeAction.description(
            name:,
            icon:,
            color: "yellow",
            i18n_scope: "post_reacting",
            changed:,
            properties: {
              reaction: {
                type: :emoji,
                required: true,
              },
              **properties,
            },
            output: {
              "reaction" => {
                "type" => %w[string null],
                "description" => "The actor's reaction on the post afterwards",
              },
              "previous_reaction" => {
                "type" => %w[string null],
                "description" => "The actor's reaction on the post before",
              },
            },
          ).merge(
            available: -> { SiteSetting.discourse_reactions_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_reactions",
          )
        end

        private

        # Toggles the reaction when `toggle?` is true for the actor's current reaction, then reports whether
        # it differs from before, so a concurrent toggle isn't reported as this node's change.
        def react(exec_ctx, item_index)
          post = ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          raise Discourse::InvalidAccess if !actor.guardian.can_see?(post)

          reaction = exec_ctx.get_node_parameter("reaction", item_index).to_s.delete(":")
          previous_reaction = reaction_of(actor, post)
          toggle(post, actor, reaction, item_index) if yield(previous_reaction, reaction)
          current_reaction = reaction_of(actor, post)

          post_output(post.reload, actor, changed: current_reaction != previous_reaction).merge(
            reaction: current_reaction,
            previous_reaction:,
          )
        end

        def reaction_of(actor, post)
          ::DiscourseReactions::ReactionManager.reaction_value_for(user: actor, post:)
        end

        def toggle(post, actor, reaction, item_index)
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
