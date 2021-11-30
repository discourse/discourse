# frozen_string_literal: true

Fabricator(:reviewable_score) do
  reviewable { Fabricate(:reviewable) }
  user { Fabricate(:user) }
  reviewable_score_type { 4 }
  status { 1 }
  score { 11.0 }
  reviewed_by { Fabricate(:user) }
end
