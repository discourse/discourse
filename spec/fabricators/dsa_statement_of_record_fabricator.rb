# frozen_string_literal: true

Fabricator(:dsa_statement_of_record) do
  reviewable_id { Fabricate(:reviewable_flagged_post).id }
  payload do
    {
      "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
      "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
      "decision_facts" => "The flagged post was removed.",
      "content_type" => ["CONTENT_TYPE_TEXT"],
      "content_date" => "2026-10-01",
      "application_date" => "2026-10-02",
      "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
      "source_type" => "SOURCE_VOLUNTARY",
      "automated_detection" => "No",
      "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
    }
  end
end
