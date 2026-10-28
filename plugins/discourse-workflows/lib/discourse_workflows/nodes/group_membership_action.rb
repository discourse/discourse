# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Add user to group and Remove user from group go through the services behind the group's members page,
    # with its permissions. Each node defines NOT_ALLOWED_ERROR, the full key of its permission error.
    module GroupMembershipAction
      include UserChangeAction

      I18N_SCOPE = "group_membership_action"

      def self.description(name:, icon:, changed:, properties: {})
        UserChangeAction.description(
          name:,
          icon:,
          color: "indigo",
          i18n_scope: I18N_SCOPE,
          changed:,
          properties: {
            group_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "groups",
              },
              ui: {
                control: :group_select,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
            **properties,
          },
          output: Schema::GROUP_SCHEMA.fetch("properties"),
        )
      end

      # Automatic groups are left out: their members can't be changed.
      def self.group_options(context)
        NodeType.load_group_options(context, ::Group.where(automatic: false))
      end

      private

      def find_actor_user_and_group(exec_ctx, item_index)
        actor, user = find_actor_and_user(exec_ctx, item_index)
        group_id = exec_ctx.get_node_parameter("group_id", item_index)
        group = ::Group.find_by(id: group_id)
        if group.nil?
          raise_node_error!(
            I18n.t("discourse_workflows.errors.group_membership_action.group_not_found", group_id:),
            item_index:,
          )
        end
        if group.automatic?
          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.group_membership_action.automatic_group",
              group: group.name,
            ),
            item_index:,
          )
        end

        # Checked before looking at the membership, so reporting nothing changed still needs the permission.
        if !actor.guardian.can_edit_group?(group)
          raise_node_error!(
            I18n.t(self.class::NOT_ALLOWED_ERROR, username: actor.username, group: group.name),
            item_index:,
          )
        end

        [actor, user, group]
      end

      # Reloaded because the services change the user (trust level, primary group) through other instances.
      def group_output(user, group, actor, changed:)
        user_output(
          user.reload,
          actor,
          changed:,
          group: serialize_group(group.reload, guardian: actor.guardian),
        )
      end
    end
  end
end
