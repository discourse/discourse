# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Badge
      class V1 < NodeType
        OPERATIONS = %w[grant revoke].freeze
        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "user_id" => {
              "type" => "integer",
            },
            "username" => {
              "type" => "string",
            },
            "badge_id" => {
              "type" => "integer",
            },
            "badge_name" => {
              "type" => "string",
            },
            "changed" => {
              "type" => "boolean",
            },
          },
        }.freeze

        description(
          name: "action:badge",
          version: "1.0",
          defaults: {
            icon: "certificate",
            color: "yellow",
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
              default: "grant",
              ui: {
                expression: true,
              },
            },
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
            },
            badge_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "badges",
              },
              ui: {
                control: :combo_box,
                dynamic_value: :badge_id,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.badge.badge_id_placeholder",
              },
            },
            **actor_property,
          },
        )

        deprecated(replaced_by: %w[action:grant_badge action:revoke_badge]) do |parameters|
          badge_parameters = parameters.slice("username", "badge_id", "actor_username")
          notes = ["discourse_workflows.node_upgrades.badge_output"]

          # An operation set by an expression can't be upgraded automatically.
          case parameters.fetch("operation", "grant")
          when "grant"
            { type: "action:grant_badge", parameters: badge_parameters, notes: }
          when "revoke"
            {
              type: "action:revoke_badge",
              parameters: badge_parameters,
              notes: [*notes, "discourse_workflows.node_upgrades.badge_revoke_all_grants"],
            }
          end
        end

        def self.load_options_context(context)
          load_badge_options(context)
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "operation" =>
                  exec_ctx.get_node_parameter("operation", item_index, default: "grant"),
                "username" => exec_ctx.get_node_parameter("username", item_index),
                "badge_id" => exec_ctx.get_node_parameter("badge_id", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          user = exec_ctx.find_user(username: config["username"])
          badge = ::Badge.find(config["badge_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          raise Discourse::InvalidAccess if !actor.guardian.can_grant_badges?(user)

          user_badges = UserBadge.where(user: user, badge: badge)

          case config["operation"]
          when "revoke"
            user_badge = user_badges.first
            BadgeGranter.revoke(user_badge, revoked_by: actor) if user_badge
            changed = user_badge.present?
          else
            last_user_badge_id = user_badges.maximum(:id)
            BadgeGranter.grant(badge, user, granted_by: actor)
            changed = user_badges.maximum(:id) != last_user_badge_id
          end

          {
            user_id: user.id,
            username: user.username,
            badge_id: badge.id,
            badge_name: badge.name,
            changed:,
          }
        end
      end
    end
  end
end
