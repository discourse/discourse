# frozen_string_literal: true
class DsaStatementOfReason::Classify
  include Service::Base

  params do
    attribute :reviewable_id, :integer
    attribute :decision_key, :string
    attribute :community_rule, :string
    attribute :category, :string

    validates :reviewable_id, :decision_key, presence: true
    validates :community_rule, inclusion: { in: DsaStatementRules.rule_names }
    validates :category, inclusion: { in: DsaStatementRules.categories }
  end

  policy :reporting_enabled
  model :reviewable
  model :statements
  policy :can_correct_classification

  transaction do
    step :classify
    step :record_classification_note
  end

  step :schedule_submission

  private

  def reporting_enabled
    SiteSetting.dsa_reporting_enabled
  end

  def fetch_reviewable(params:, guardian:)
    Reviewable.viewable_by(guardian.user).find_by(id: params.reviewable_id)
  end

  def fetch_statements(params:, reviewable:)
    DsaStatementOfReason
      .where(reviewable_id: reviewable.id, decision_key: params.decision_key)
      .where(status: :failed)
      .or(
        DsaStatementOfReason.where(
          reviewable_id: reviewable.id,
          decision_key: params.decision_key,
          status: :pending,
          classified_at: nil,
        ),
      )
  end

  def can_correct_classification(statements:, guardian:)
    statements.all? do |statement|
      statement.classified_at.nil? || guardian.is_admin? && statement.failed?
    end
  end

  def classify(statements:, params:, guardian:)
    statements.reload.lock.each do |statement|
      statement.classify!(
        community_rule: params.community_rule,
        category: params.category,
        actor: guardian.user,
      )
    end
  end

  def record_classification_note(reviewable:, params:, guardian:)
    reviewable.reviewable_notes.create!(
      user: guardian.user,
      content:
        I18n.t(
          "dsa.classification_note",
          rule: I18n.t("js.review.dsa.rules.#{params.community_rule}"),
          category: I18n.t("js.review.dsa.categories.#{params.category}"),
        ),
    )
  end

  def schedule_submission(reviewable:)
    Jobs.enqueue(:submit_dsa_statements)
    Jobs.enqueue(:notify_reviewable, reviewable_id: reviewable.id)
  end
end
