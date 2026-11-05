# frozen_string_literal: true

class DsaStatementOfRecord::Classify
  include Service::Base

  policy :staff
  policy :classification_enabled

  params base_class: DsaStatementOfRecord::ClassificationContract do
    attribute :reviewable_id, :integer
    attribute :statement_ids, :array

    validates :reviewable_id, :statement_ids, presence: true
  end

  model :community_rule

  transaction do
    model :reviewable
    model :statements
    policy :current_statements
    step :classify
    model :reviewable_note, :save_note
  end

  private

  def staff(guardian:)
    guardian.is_staff?
  end

  def classification_enabled
    DsaStatementOfRecord.classification_enabled?
  end

  def fetch_community_rule(params:)
    params.rule
  end

  def fetch_reviewable(params:, guardian:)
    reviewable =
      Reviewable.viewable_by(guardian.user, preload: false).find_by(id: params.reviewable_id)

    reviewable&.lock!
  end

  def fetch_statements(reviewable:)
    reviewable.dsa_statement_of_records.pending.order(:id).lock.to_a
  end

  def current_statements(statements:, params:)
    params.statement_ids.map(&:to_s).sort == statements.map(&:id).sort
  end

  def classify(statements:, community_rule:, params:, guardian:)
    statements.each do |statement|
      statement.classify!(community_rule:, category: params.category, classified_by: guardian.user)
    end
  end

  def save_note(reviewable:, statements:, guardian:)
    note = reviewable.reviewable_notes.new
    note.update(user: guardian.user, content: statements.first.classification_note)
    note
  end
end
