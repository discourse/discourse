# frozen_string_literal: true

Fabricator(:reviewable_outcome) do
  reviewable { Fabricate(:reviewable_flagged_post) }
  outcome_source "human"
  legal_basis "tos_violation"
end
