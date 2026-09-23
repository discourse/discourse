# frozen_string_literal: true

class ReviewableOutcome::AddRestrictions
  include Service::Base

  params do
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

  only_if :reporting_enabled_for_reviewable? do
    model :outcome, optional: true
    transaction { step :add_restrictions }
  end

  private

  def reporting_enabled_for_reviewable?(params:)
    SiteSetting.reviewable_outcome_reporting_enabled && params.reviewable_id.present?
  end

  def fetch_outcome(params:)
    ReviewableOutcome.find_by(reviewable_id: params.reviewable_id)
  end

  def add_restrictions(outcome:, params:)
    return unless outcome

    reviewable = outcome.reviewable
    reviewed_user_id =
      reviewable.target_type == "User" ? reviewable.target_id : reviewable.target_created_by_id
    return unless reviewed_user_id == params.user_id

    outcome.with_lock do
      outcome.restriction_type = (Array(outcome.restriction_type) | params.restriction_type)
      outcome.save!
    end
  end
end
