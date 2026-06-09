# frozen_string_literal: true

Fabricator(:post_event_invitee, from: "DiscoursePostEvent::Invitee") do
  event
  user
  status { |attrs| attrs[:status] || nil }
end
