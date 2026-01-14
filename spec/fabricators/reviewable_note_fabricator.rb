# frozen_string_literal: true

Fabricator(:reviewable_note) do
  content { "This is a sample reviewable note for testing purposes." }
  user { Fabricate(:admin) }
  reviewable { Fabricate(:reviewable_flagged_post) }
end
