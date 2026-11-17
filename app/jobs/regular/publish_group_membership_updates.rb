# frozen_string_literal: true

module Jobs
  class PublishGroupMembershipUpdates < ::Jobs::Base
    def execute(args)
      available_types = [Group::AUTO_GROUPS_ADD, Group::AUTO_GROUPS_REMOVE]
      raise Discourse::InvalidParameters.new(:type) if !available_types.include?(args[:type])

      group = Group.find_by(id: args[:group_id])
      return if !group

      added_members = args[:type] == Group::AUTO_GROUPS_ADD
      system_user = Discourse.system_user

      # The membership may have changed again since it was enqueued: only report what still holds.
      member_ids = group.group_users.where(user_id: args[:user_ids]).select(:user_id)
      users = User.human_users.where(id: args[:user_ids])
      users = added_members ? users.where(id: member_ids) : users.where.not(id: member_ids)

      users.each do |user|
        if added_members
          group.trigger_user_added_event(user, group.automatic?, acting_user: system_user)
        else
          group.trigger_user_removed_event(user, acting_user: system_user)
        end
      end
    end
  end
end
