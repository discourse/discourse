# frozen_string_literal: true
Fabricator(:live_room, class_name: "Live::Room") do
  name { sequence(:live_room_name) { |i| "Live #{i}" } }
  public { false }
  creator { Fabricate(:user) }
end

Fabricator(:live_ephemeral_room, from: :live_room) do
  ephemeral true
  last_occupied_at { Time.current }
end
