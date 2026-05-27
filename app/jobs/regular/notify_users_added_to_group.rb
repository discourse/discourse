# frozen_string_literal: true

module Jobs
  class NotifyUsersAddedToGroup < ::Jobs::Base
    def execute(args)
      user_ids = args[:user_ids]
      group_id = args[:group_id]
      return if group_id.blank? || user_ids.blank?

      group = Group.find_by(id: group_id)
      return if group.nil?

      User.where(id: user_ids).find_each { |user| group.notify_added_to_group(user) }
    end
  end
end
