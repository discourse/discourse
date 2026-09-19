# frozen_string_literal: true

Fabricator(:voice_session, class_name: "Voice::Session") do
  user
  room { Fabricate(:voice_room) }
  joined_at { 1.hour.ago }
  left_at { Time.current }
end
