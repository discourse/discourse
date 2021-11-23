# frozen_string_literal: true

Fabricator(:reviewable_score) do
  reviewable_id
  user { Fabricate(:user) }
  reviewable_score_type { 4 }
  status { 1 }
  score { 11.0 }
  reviewed_by { Fabricate(:user) }
end
