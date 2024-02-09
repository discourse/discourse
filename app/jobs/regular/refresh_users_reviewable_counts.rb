# frozen_string_literal: true

class Jobs::RefreshUsersReviewableCounts < ::Jobs::Base
  def execute(args)
    group_ids = args[:group_ids]
    return if group_ids.blank?
    User
      .human_users
      .where(id: GroupUser.where(group_id: group_ids).distinct.select(:user_id))
      .each(&:publish_reviewable_counts)
  end
end
