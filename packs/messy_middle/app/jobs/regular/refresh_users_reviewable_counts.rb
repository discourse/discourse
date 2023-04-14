# frozen_string_literal: true

class Jobs::RefreshUsersReviewableCounts < ::Jobs::Base
  def execute(args)
    group_ids = args[:group_ids]
    return if group_ids.blank?
    User.where(id: GroupUser.where(group_id: group_ids).distinct.pluck(:user_id)).each(
      &:publish_reviewable_counts
    )
  end
end
