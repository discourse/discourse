# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Badge
      class V1 < NodeType
        simulation { supported "grant", "revoke" }

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

        def self.load_options_context(context)
          case context.method_name
          when "badges"
            ::Badge
              .where(enabled: true)
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |item, item_index|
              operation = exec_ctx.get_node_parameter("operation", item_index, default: "grant")
              config = resolve_config(exec_ctx, item:, item_index:, operation:)
              wrap(process(exec_ctx, config.merge("operation" => operation), item_index))
            end

          [items]
        end

        def resolve_config(exec_ctx, item:, item_index:, operation:)
          {
            "username" => exec_ctx.get_node_parameter("username", item_index),
            "badge_id" => exec_ctx.get_node_parameter("badge_id", item_index),
          }
        end

        def simulate_item(exec_ctx, dispatch)
          user, badge, actor = resolve_targets(exec_ctx, dispatch.config, dispatch.item_index)

          effect = dispatch.operation == "revoke" ? :badge_revoked : :badge_granted
          exec_ctx.record_effect(
            effect,
            { username: user.username, badge_id: badge.id },
            item_index: dispatch.item_index,
          )

          held = UserBadge.exists?(user: user, badge: badge)
          changed = dispatch.operation == "revoke" ? held : (!held || badge.multiple_grant?)
          wrap(badge_output(user, badge, changed:))
        end

        private

        def process(exec_ctx, config, item_index)
          user, badge, actor = resolve_targets(exec_ctx, config, item_index)

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

          badge_output(user, badge, changed:)
        end

        def resolve_targets(exec_ctx, config, item_index)
          user = exec_ctx.read_user(username: config["username"])
          badge =
            exec_ctx.read_record(:badge, config["badge_id"]) ||
              raise(ActiveRecord::RecordNotFound, "Couldn't find Badge #{config["badge_id"]}")
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          raise Discourse::InvalidAccess if !actor.guardian.can_grant_badges?(user)

          [user, badge, actor]
        end

        def badge_output(user, badge, changed:)
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
