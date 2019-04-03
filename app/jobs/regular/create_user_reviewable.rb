class Jobs::CreateUserReviewable < Jobs::Base
  def execute(args)
    raise Discourse::InvalidParameters unless args[:user_id].present?

    if user = User.find_by(id: args[:user_id])
      return if user.approved?

      reviewable = ReviewableUser.create!(target: user, created_by: Discourse.system_user, reviewable_by_moderator: true)
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        force_review: true
      )
    end

  end
end
