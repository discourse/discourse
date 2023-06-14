# frozen_string_literal: true

Fabricator(:poll, class_name: "Poll") do
  post
  name { sequence(:name) { |i| "Poll #{i}" } }
end

Fabricator(:poll_option, class_name: "PollOption") do
  poll
  html { sequence(:html) { |i| "Poll Option #{i}" } }
  digest { sequence(:digest) { |i| "#{i}" } }
end

Fabricator(:poll_vote, class_name: "PollVote") do
  poll
  poll_option
  user
end
