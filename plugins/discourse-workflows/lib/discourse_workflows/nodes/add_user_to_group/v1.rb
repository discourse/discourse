# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module AddUserToGroup
      class V1 < NodeType
        include GroupMembershipAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.group_membership_action.add_not_allowed"

        description(
          GroupMembershipAction.description(
            name: "action:add_user_to_group",
            icon: "user-plus",
            changed:
              "False when the user was already in the group and, with set_primary_group, it was already their primary group",
            properties: {
              set_primary_group: {
                type: :boolean,
                required: false,
                default: false,
                ui: {
                  control: :boolean,
                  expression: true,
                },
              },
              notify_user: {
                type: :boolean,
                required: false,
                default: false,
                ui: {
                  control: :boolean,
                  expression: true,
                },
              },
            },
          ),
        )

        def self.load_options_context(context)
          GroupMembershipAction.group_options(context)
        end

        private

        # Like adding a member from the group's page: logged, and the user is messaged only when asked.
        def change_user(exec_ctx, item_index)
          actor, user, group = find_actor_user_and_group(exec_ctx, item_index)
          notify_user = exec_ctx.get_node_parameter("notify_user", item_index, default: false)
          set_primary_group =
            exec_ctx.get_node_parameter("set_primary_group", item_index, default: false)

          changed = add_member(actor, group, user, notify_user)
          changed = make_primary_group(user.reload, group) || changed if set_primary_group

          group_output(user, group, actor, changed:)
        end

        # The adder reports only the users it added, so a concurrent add of the same user isn't reported twice.
        def add_member(actor, group, user, notify_user)
          result =
            ::GroupMemberAdder.add(
              actor.guardian,
              group,
              user_id: user.id,
              notify_users: notify_user == true,
            )
          result[:added_usernames].include?(user.username)
        rescue ::GroupMemberAdder::AlreadyMembers
          false
        end

        def make_primary_group(user, group)
          return false if user.primary_group_id == group.id

          user.update!(primary_group_id: group.id)
        end
      end
    end
  end
end
