# frozen_string_literal: true

class Jobs::CreateUserReviewable < ::Jobs::Base
  attr_reader :reviewable

  def execute(args)
    raise Discourse::InvalidParameters if args[:user_id].blank?

    reason = nil
    reason ||= :must_approve_users if SiteSetting.must_approve_users?
    reason ||= :invite_only if SiteSetting.invite_only?

    return unless reason

    if user = User.find_by(id: args[:user_id])
      return if user.approved?

      @reviewable =
        ReviewableUser.needs_review!(
          target: user,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
          payload: ReviewableUser.payload_for(user),
        )

      if @reviewable.created_new
        @reviewable.add_score(
          Discourse.system_user,
          ReviewableScore.types[:needs_approval],
          reason: reason,
          force_review: true,
        )
      end
    end
  end
end
