# frozen_string_literal: true

module Jobs
  class PublishGroupMembershipUpdates < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:type) if !%w[add remove].include?(args[:type])

      group = Group.find_by(id: args[:group_id])
      return if !group

      added_members = args[:type] == 'add'

      User.human_users.where(id: args[:user_ids]).each do |user|
        if added_members
          group.trigger_user_added_event(user, group.automatic?)
        else
          group.trigger_user_removed_event(user)
        end
      end
    end
  end
end
