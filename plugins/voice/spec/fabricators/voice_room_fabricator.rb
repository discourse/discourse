# frozen_string_literal: true
Fabricator(:voice_room, class_name: "Voice::Room") do
  name { sequence(:voice_room_name) { |i| "Voice #{i}" } }
  public { false }
  creator { Fabricate(:user) }
end

Fabricator(:voice_ephemeral_room, from: :voice_room) do
  ephemeral true
  last_occupied_at { Time.current }
end
