# frozen_string_literal: true

class ReviewableOutcome::AddRestrictions
  include Service::Base

  params do
    attribute :outcome_id, :integer
    attribute :reviewable_id, :integer
    attribute :user_id, :integer
    attribute :restriction_type, :array

    validate :valid_restriction_types

    private

    def valid_restriction_types
      if restriction_type.present? &&
           restriction_type.all? { |type| ReviewableOutcome::RESTRICTION_TYPES.include?(type) }
        return
      end

      errors.add(:restriction_type, :inclusion)
    end
  end

  only_if :reporting_enabled_for_outcome? do
    model :outcome
    policy :outcome_matches_penalized_user
    transaction { step :add_restrictions }
  end

  private

  def reporting_enabled_for_outcome?(params:)
    SiteSetting.reviewable_outcome_reporting_enabled && params.outcome_id.present?
  end

  def fetch_outcome(params:)
    ReviewableOutcome.find_by(id: params.outcome_id)
  end

  def outcome_matches_penalized_user(outcome:, params:)
    reviewable = outcome.reviewable
    reviewable && outcome.reviewable_id == params.reviewable_id &&
      (
        reviewable.target_created_by_id == params.user_id ||
          (reviewable.target_type == "User" && reviewable.target_id == params.user_id)
      )
  end

  def add_restrictions(outcome:, params:)
    outcome.with_lock do
      outcome.restriction_type = (Array(outcome.restriction_type) | params.restriction_type)
      outcome.save!
    end
  end
end
