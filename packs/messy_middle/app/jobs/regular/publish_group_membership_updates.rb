# frozen_string_literal: true

module Jobs
  class PublishGroupMembershipUpdates < ::Jobs::Base
    def execute(args)
      available_types = [Group::AUTO_GROUPS_ADD, Group::AUTO_GROUPS_REMOVE]
      raise Discourse::InvalidParameters.new(:type) if !available_types.include?(args[:type])

      group = Group.find_by(id: args[:group_id])
      return if !group

      added_members = args[:type] == Group::AUTO_GROUPS_ADD

      User
        .human_users
        .where(id: args[:user_ids])
        .each do |user|
          if added_members
            group.trigger_user_added_event(user, group.automatic?)
          else
            group.trigger_user_removed_event(user)
          end
        end
    end
  end
end
