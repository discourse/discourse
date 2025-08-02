# frozen_string_literal: true

Fabricator(:poll) do
  post
  name { sequence(:name) { |i| "Poll #{i}" } }
end

Fabricator(:poll_regular, from: :poll) { type "regular" }

Fabricator(:poll_multiple, from: :poll) { type "multiple" }

Fabricator(:poll_ranked_choice, from: :poll) { type "ranked_choice" }

Fabricator(:poll_option) do
  poll
  html { sequence(:html) { |i| "Poll Option #{i}" } }
  digest { sequence(:digest) { |i| "#{i}" } }
end

Fabricator(:poll_vote) do
  poll
  poll_option
  user
end
