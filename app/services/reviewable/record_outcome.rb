# frozen_string_literal: true

class Reviewable::RecordOutcome
  include Service::Base

  params do
    attribute :outcome_source, :string
    attribute :restriction_type, :array

    validates :outcome_source, inclusion: { in: ReviewableOutcome::OUTCOME_SOURCES }
  end

  only_if :reporting_enabled? do
    model :outcome, :create_outcome
  end

  private

  def reporting_enabled?
    SiteSetting.reviewable_outcome_reporting_enabled
  end

  def create_outcome(reviewable:, params:)
    reviewable.reviewable_outcomes.create(
      outcome_source: params.outcome_source,
      legal_basis: reviewable.potentially_illegal? ? "illegal content" : "tos_violation",
      restriction_type: params.restriction_type,
    )
  end
end
