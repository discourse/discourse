# frozen_string_literal: true

require "discourse_dev/reviewable"
require "faker"

module DiscourseDev
  class ReviewableUser < Reviewable
    def populate!
      reasons = %i[must_approve_users invite_only suspect_user]
      @users
        .sample(reasons.size)
        .zip(reasons)
        .each do |(user, reason)|
          reviewable =
            ::ReviewableUser.needs_review!(
              target: user,
              created_by: Discourse.system_user,
              reviewable_by_moderator: true,
              payload: {
                username: user.username,
                name: user.name,
                email: user.email,
                bio: user.user_profile&.bio_raw,
                website: user.user_profile&.website,
              },
            )

          reviewable.add_score(
            Discourse.system_user,
            ReviewableScore.types[:needs_approval],
            reason:,
            force_review: true,
          )
        end
    end
  end
end
