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
            reason: {
              type: :string,
              required: false,
              ui: {
                description_key: "admin.badges.reason_help",
              },
              display_options: {
                show: {
                  operation: ["grant"],
                },
                hide: {
                  badge_id: [
                    { condition: { metadata_flag: { collection: "badges", flag: "hide_reason" } } },
                  ],
                },
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
              .select(:id, :name, :system, :show_posts)
              .filter_map do |badge|
                if context.matches_filter?(badge.name)
                  { id: badge.id, name: badge.name, hide_reason: reason_hidden?(badge) }
                end
              end
          end
        end

        def self.reason_hidden?(badge)
          badge.system? && !badge.show_posts?
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
          guardian = actor.guardian
          raise Discourse::InvalidAccess if !guardian.can_grant_badges?(user)

          user_badges = UserBadge.where(user: user, badge: badge)

          case config["operation"]
          when "revoke"
            user_badge = user_badges.first
            BadgeGranter.revoke(user_badge, revoked_by: actor) if user_badge
            changed = user_badge.present?
          else
            post =
              find_reason_post(exec_ctx, item_index, guardian:) unless self.class.reason_hidden?(
              badge,
            )

            last_user_badge_id = user_badges.maximum(:id)
            BadgeGranter.grant(badge, user, granted_by: actor, post_id: post&.id)
            changed = user_badges.maximum(:id) != last_user_badge_id
          end

          {
            user_id: user.id,
            username: user.username,
            badge_id: badge.id,
            badge_name: badge.name,
            changed:,
          }
        rescue BadgeGranter::InvalidReason => error
          raise NodeError, error.message
        end

        def find_reason_post(exec_ctx, item_index, guardian:)
          reason = exec_ctx.get_node_parameter("reason", item_index).to_s.strip
          reference = /\A(?:(post|topic):)?([0-9]+)\z/.match(reason)
          return BadgeGranter.post_for_reason(reason, guardian:) if !reference

          type, id = reference.captures
          if !type
            raise NodeError,
                  I18n.t("discourse_workflows.errors.badge.reason_id_requires_prefix", id:)
          end

          post = type == "post" ? ::Post.find_by(id:) : ::Post.find_by(topic_id: id, post_number: 1)
          if !post
            raise NodeError,
                  I18n.t("discourse_workflows.errors.badge.reason_id_not_found", reference: reason)
          end

          guardian.ensure_can_see!(post)
          post
        end
      end
    end
  end
end
