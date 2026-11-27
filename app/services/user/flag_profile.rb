# frozen_string_literal: true

class User::FlagProfile
  include Service::Base

  params do
    attribute :username, :string
    attribute :flag_type_id, :integer
    attribute :message, :string
    attribute :confirmed, :string

    before_validation { self.message = message&.strip }

    validates :username, :flag_type_id, presence: true
    validates :message, length: { maximum: 500 }, allow_nil: true
  end

  model :user
  policy :can_flag_profile
  model :flag
  policy :message_meets_minimum
  policy :illegal_flag_confirmed
  step :record_report

  private

  def fetch_user(params:)
    User.find_by_username(params.username)
  end

  def can_flag_profile(guardian:, user:)
    guardian.can_flag_profile?(user)
  end

  def fetch_flag(params:, guardian:)
    guardian.allowed_profile_flags.find_by(id: params.flag_type_id)
  end

  def message_meets_minimum(params:, flag:)
    return true unless flag.require_message?
    params.message.present? && params.message.length >= SiteSetting.min_personal_message_post_length
  end

  def illegal_flag_confirmed(params:, flag:)
    flag.name_key != "illegal" || params.confirmed == "true"
  end

  def record_report(user:, flag:, params:, guardian:)
    profile = user.user_profile
    context[:score] = profile.with_lock do
      existing =
        ReviewableScore.pending.find_by(
          reviewable: ReviewableFlaggedProfile.pending.where(target: profile),
          user: guardian.user,
        )
      next existing if existing

      potentially_illegal = flag.name_key == "illegal"
      reviewable =
        ReviewableFlaggedProfile.needs_review!(
          target: profile,
          target_created_by: user,
          created_by: guardian.user,
          potential_spam: false,
          potentially_illegal:,
          reviewable_by_moderator: true,
        )
      limiter = PostAction.rate_limiter_for(guardian.user, :flag)
      limiter.performed!
      UserProfile.current_transaction.after_rollback { limiter.rollback! }

      if reviewable.created_new || reviewable.reopened
        reviewable.capture_profile!(profile, potentially_illegal:)
      end
      reviewable.add_score(
        guardian.user,
        flag.id,
        reason: (:profile_flag_message if flag.require_message?),
        context: (params.message if flag.require_message?),
        force_review: true,
      )
    end
  end
end
