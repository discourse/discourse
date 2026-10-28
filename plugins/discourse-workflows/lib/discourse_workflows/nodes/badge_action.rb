# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Grant badge and Revoke badge go through BadgeGranter like the admin badge page, for staff only. Each node
    # defines NOT_ALLOWED_ERROR, the full key of its permission error.
    module BadgeAction
      include UserChangeAction

      I18N_SCOPE = "badge_action"

      def self.description(name:, color:, changed:)
        UserChangeAction.description(
          name:,
          icon: "certificate",
          color:,
          i18n_scope: I18N_SCOPE,
          changed:,
          properties: {
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
                none: "discourse_workflows.badge_action.badge_id_placeholder",
              },
            },
            post_id: {
              type: :string,
              required: false,
            },
          },
          output: Schema::BADGE_ENTITY_SCHEMA.fetch("properties"),
        )
      end

      private

      def find_actor_user_and_badge(exec_ctx, item_index)
        actor, user = find_actor_and_user(exec_ctx, item_index)
        badge_id = exec_ctx.get_node_parameter("badge_id", item_index)
        badge = ::Badge.find_by(id: badge_id)
        if badge.nil?
          raise_node_error!(
            I18n.t("discourse_workflows.errors.badge_action.badge_not_found", badge_id:),
            item_index:,
          )
        end

        # Checked before looking at the user's badges, so reporting nothing changed still needs the permission.
        if !actor.guardian.can_grant_badges?(user)
          raise_node_error!(
            I18n.t(self.class::NOT_ALLOWED_ERROR, username: actor.username, target: user.username),
            item_index:,
          )
        end

        [actor, user, badge]
      end

      def badge_post_id(exec_ctx, item_index)
        value = exec_ctx.get_node_parameter("post_id", item_index).to_s.presence
        return if value.nil?

        post_id = Integer(value, 10, exception: false)
        badge_post_not_found!(value, item_index) if post_id.nil?
        post_id
      end

      def badge_post_not_found!(post_id, item_index)
        raise_node_error!(
          I18n.t("discourse_workflows.errors.badge_action.post_not_found", post_id:),
          item_index:,
        )
      end

      # Reloaded for its grant count.
      def badge_output(user, badge, actor, changed:)
        user_output(user, actor, changed:, badge: serialize_badge(badge.reload))
      end
    end
  end
end
