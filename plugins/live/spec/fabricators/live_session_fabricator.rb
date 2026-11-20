# frozen_string_literal: true

Fabricator(:live_session, class_name: "Live::Session") do
  user
  room { Fabricate(:live_room) }
  joined_at { 1.hour.ago }
  left_at { Time.current }
end
