# frozen_string_literal: true
Fabricator(:dsa_statement_of_reason) do
  reviewable
  decision_key { SecureRandom.uuid }
  action_name "delete_and_agree"
  target_type "Post"
  target_id { sequence(:dsa_target_id) }
  puid { SecureRandom.uuid }
  community_rule "spam"
  classified_at { Time.zone.now }
  payload do |attributes|
    DsaStatementRules.fetch("spam").merge(
      "puid" => attributes[:puid],
      "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      "content_type" => ["CONTENT_TYPE_TEXT"],
      "content_date" => Time.zone.today.iso8601,
      "application_date" => Time.zone.today.iso8601,
      "category" => "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
      "territorial_scope" => ["DE"],
      "source_type" => "SOURCE_VOLUNTARY",
      "automated_detection" => "No",
      "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
    )
  end
end
