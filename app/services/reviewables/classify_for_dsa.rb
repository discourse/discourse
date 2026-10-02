# frozen_string_literal: true

class Reviewables::ClassifyForDsa
  include Service::Base

  params do
    attribute :reviewable_id, :integer
    attribute :dsa_category, :string
    attribute :dsa_subcategory, :string
    attribute :dsa_subcategory_other, :string

    before_validation do
      self.dsa_subcategory = dsa_subcategory.presence
      self.dsa_subcategory_other = other_keyword? ? dsa_subcategory_other.to_s.strip : nil
    end

    validates :reviewable_id, presence: true
    validates :dsa_subcategory_other,
              presence: true,
              length: {
                maximum: Reviewable::DsaTaxonomy::OTHER_KEYWORD_MAX_LENGTH,
              },
              if: :other_keyword?
    validate :category_in_taxonomy
    validate :subcategory_in_category, if: :dsa_subcategory

    def classification
      slice(:dsa_category, :dsa_subcategory, :dsa_subcategory_other)
    end

    def legal_basis
      Reviewable::DsaTaxonomy.legal_basis_for(dsa_category)
    end

    private

    def other_keyword?
      dsa_subcategory == Reviewable::DsaTaxonomy::OTHER_KEYWORD
    end

    def category_in_taxonomy
      errors.add(:dsa_category, :inclusion) if legal_basis.nil?
    end

    def subcategory_in_category
      return if Reviewable::DsaTaxonomy.keywords_for(dsa_category)&.include?(dsa_subcategory)
      errors.add(:dsa_subcategory, :inclusion)
    end
  end

  policy :dsa_reporting_enabled
  model :reviewable
  policy :can_review_target
  policy :requires_dsa_classification
  policy :category_matches_legal_basis

  transaction do
    step :classify
    step :log_classification
  end

  step :notify_moderators

  private

  def dsa_reporting_enabled
    SiteSetting.enable_dsa_reporting
  end

  def fetch_reviewable(params:, guardian:)
    Reviewable.viewable_by(guardian.user, preload: false).find_by(id: params.reviewable_id)
  end

  def can_review_target(reviewable:, guardian:)
    reviewable.can_review_target?(guardian)
  end

  def requires_dsa_classification(reviewable:)
    reviewable.legal_basis.present?
  end

  def category_matches_legal_basis(reviewable:, params:)
    reviewable.legal_basis == params.legal_basis
  end

  def classify(reviewable:, params:)
    reviewable.update!(params.classification)
  end

  def log_classification(reviewable:, params:, guardian:)
    reviewable.log_history(
      :dsa_classified,
      guardian.user,
      edited: params.classification.merge(legal_basis: reviewable.legal_basis),
    )
  end

  # Refreshes review queue counts and marks the item as handled for other moderators.
  def notify_moderators(reviewable:, guardian:)
    Jobs.enqueue(
      :notify_reviewable,
      reviewable_id: reviewable.id,
      performing_username: guardian.user.username,
      updated_reviewable_ids: [reviewable.id],
    )
  end
end
