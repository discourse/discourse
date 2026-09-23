# frozen_string_literal: true

class Reviewable::RecordOutcome
  include Service::Base

  params do
    attribute :outcome_source, :string
    attribute :restriction_type, :array

    validates :outcome_source, inclusion: { in: ReviewableOutcome::OUTCOME_SOURCES }
  end

  only_if :reporting_enabled? do
    model :outcome, :record_outcome
  end

  private

  def reporting_enabled?
    SiteSetting.reviewable_outcome_reporting_enabled
  end

  def record_outcome(reviewable:, params:)
    reviewable.with_lock do
      outcome = reviewable.reviewable_outcome || reviewable.build_reviewable_outcome
      outcome.outcome_source = params.outcome_source
      outcome.legal_basis = reviewable.potentially_illegal? ? "illegal content" : "tos_violation"
      outcome.restriction_type = params.restriction_type
      outcome.save
      outcome
    end
  end
end
