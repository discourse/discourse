# frozen_string_literal: true

class DsaStatementOfRecord::Classify
  include Service::Base

  policy :staff
  policy :classification_enabled

  params do
    attribute :reviewable_id, :integer
    attribute :community_rule, :string
    attribute :category, :string
    attribute :statement_ids, :array

    validates :reviewable_id, :community_rule, :statement_ids, presence: true
    validates :category, inclusion: { in: DsaStatementOfRecord::CATEGORIES }
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
    DsaStatementOfRecord.community_rules.find { |rule| rule["id"] == params.community_rule }
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

  def save_note(reviewable:, community_rule:, params:, guardian:)
    note = reviewable.reviewable_notes.new

    note.update(
      user: guardian.user,
      content:
        I18n.t(
          "dsa_statements.classification_note",
          locale: SiteSetting.default_locale,
          ground: community_rule["ground"],
          category:
            I18n.t(
              "dsa_statements.categories.#{params.category}",
              locale: SiteSetting.default_locale,
            ),
        ),
    )
    note
  end
end
