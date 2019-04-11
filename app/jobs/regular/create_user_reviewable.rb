class Jobs::CreateUserReviewable < Jobs::Base
  def execute(args)
    raise Discourse::InvalidParameters unless args[:user_id].present?

    reason = nil
    reason ||= :must_approve_users if SiteSetting.must_approve_users?
    reason ||= :invite_only if SiteSetting.invite_only?

    return unless reason

    if user = User.find_by(id: args[:user_id])
      return if user.approved?

      reviewable = ReviewableUser.create!(
        target: user,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
        payload: {
          username: user.username,
          name: user.name,
          email: user.email
        }
      )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        reason: reason,
        force_review: true
      )
    end

  rescue ActiveRecord::RecordNotUnique
    # If the reviewable is somehow queued twice, we can ignore.
  end
end
