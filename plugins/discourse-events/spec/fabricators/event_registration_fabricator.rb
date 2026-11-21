# frozen_string_literal: true

Fabricator(:event_registration, from: "DiscourseEvents::Events::Registration") do
  transient :member
  member { Fabricate(:user) }
  event
  user_id { |attrs| attrs[:member].id }
  username { |attrs| attrs[:member].username }
  email { |attrs| attrs[:member].email }
  submission_key { SecureRandom.uuid }
  recurring false
  occurrence_starts_at { |attrs| attrs[:event].starts_at }
  definition do
    {
      title: "Registration",
      fields: [{ id: "notes", type: "text", label: "Notes", required: false }],
    }
  end
  answers { { notes: "Meet me by the door." } }
end
