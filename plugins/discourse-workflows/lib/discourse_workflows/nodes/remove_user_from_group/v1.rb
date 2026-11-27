# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RemoveUserFromGroup
      class V1 < NodeType
        include GroupMembershipAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.group_membership_action.remove_not_allowed"

        description(
          GroupMembershipAction.description(
            name: "action:remove_user_from_group",
            icon: "user-minus",
            changed: "False when the user wasn't in the group",
          ),
        )

        def self.load_options_context(context)
          GroupMembershipAction.group_options(context)
        end

        private

        # Like removing a member from the group's page, owners included: logged, without a message to the user.
        def change_user(exec_ctx, item_index)
          actor, user, group = find_actor_user_and_group(exec_ctx, item_index)
          changed = remove_member(actor, group, user)

          group_output(user, group, actor, changed:)
        end

        # The remover reports only the users it removed. It raises when the user is still a member without
        # having been removed, which happens when a concurrent request adds them back.
        def remove_member(actor, group, user)
          result = ::GroupMemberRemover.remove(actor.guardian, group, user_id: user.id)
          result[:usernames].include?(user.username)
        rescue Discourse::InvalidParameters
          false
        end
      end
    end
  end
end
