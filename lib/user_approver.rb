# frozen_string_literal: true

class UserApprover
  def self.approve(guardian, user)
    guardian.ensure_can_approve!(user)
    reviewable = ReviewableUser.find_by(target: user)
    if !reviewable
      job = Jobs::CreateUserReviewable.new
      job.execute(user_id: user.id)
      reviewable =
        job.reviewable ||
          ReviewableUser.needs_review!(
            target: user,
            created_by: Discourse.system_user,
            reviewable_by_moderator: true,
            payload: ReviewableUser.payload_for(user),
          )
    end

    reviewable.perform(guardian.user, :approve_user, allow_reviewed: true)
  end
end
