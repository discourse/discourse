# frozen_string_literal: true

class Jobs::RefreshUsersReviewableCounts < ::Jobs::Base
  def execute(args)
    user_ids = args[:user_ids]
    return if user_ids.blank?
    User.where(id: user_ids).each(&:publish_reviewable_counts)
  end
end
