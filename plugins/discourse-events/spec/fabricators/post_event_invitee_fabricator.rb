# frozen_string_literal: true

Fabricator(:post_event_invitee, from: "DiscourseEvents::Events::Invitee") do
  event
  user
  status { |attrs| attrs[:status] || nil }
end
