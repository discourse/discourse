# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Flag
    include Service::Base

    params do
      attribute :boost_id, :integer
      attribute :flag_type_id, :integer

      validates :boost_id, presence: true
      validates :flag_type_id,
                presence: true,
                inclusion: {
                  in: -> { ::ReviewableScore.types.values },
                }
    end

    model :boost
    policy :can_flag_boost
    model :existing_reviewable, optional: true
    policy :can_flag_again

    transaction do
      model :reviewable, :create_reviewable
      step :add_score
    end

    private

    def fetch_boost(params:)
      DiscourseBoosts::Boost.includes(:post, :user).find_by(id: params.boost_id)
    end

    def can_flag_boost(guardian:, boost:)
      guardian.user.present? && !guardian.user.silenced? && boost.user_id != guardian.user.id &&
        guardian.can_see?(boost.post)
    end

    def fetch_existing_reviewable(boost:)
      Reviewable.includes(:reviewable_scores).find_by(target: boost)
    end

    def can_flag_again(guardian:, existing_reviewable:, params:)
      return true if existing_reviewable.blank?

      scores = existing_reviewable.reviewable_scores
      return false if scores.any? { |rs| rs.user == guardian.user && rs.pending? }
      if scores.any? { |rs| rs.reviewable_score_type == params.flag_type_id && rs.pending? }
        return false
      end

      existing_reviewable.pending? ||
        existing_reviewable.updated_at < SiteSetting.cooldown_hours_until_reflag.to_i.hours.ago
    end

    def create_reviewable(boost:, params:, guardian:)
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: guardian.user,
        target: boost,
        target_created_by: boost.user,
        reviewable_by_moderator: true,
        potential_spam: params.flag_type_id == ReviewableScore.types[:spam],
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    def add_score(reviewable:, guardian:, params:)
      reviewable.add_score(guardian.user, params.flag_type_id)
    end
  end
end
