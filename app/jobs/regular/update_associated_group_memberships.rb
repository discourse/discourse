# frozen_string_literal: true

module Jobs
  class UpdateAssociatedGroupMemberships < ::Jobs::Base

    def execute
      Group.where("associated_groups IS NOT NULL").each do |group|
        group.associated_groups.split('|').each do |associated_group|
          parts = associated_group.split(':')

          UserAssociatedGroup.joins("INNER JOIN users ON user_associated_groups.user_id = users.id")
            .where("provider_name = ? AND group = ?", *parts).each do |uag|
              user = User.find(uag.user_id)
              group.add(user)
              GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
            end
        end

        Group.reset_counters(group.id, :group_users)
      end
    end
  end
end
