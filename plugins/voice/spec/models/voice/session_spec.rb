# frozen_string_literal: true

RSpec.describe Voice::Session do
  fab!(:user)
  fab!(:room, :voice_room)

  describe "#accompanied_seconds" do
    let(:started_at) { Time.zone.parse("2026-09-01 10:00") }
    let(:session) do
      Fabricate(
        :voice_session,
        user: user,
        room: room,
        joined_at: started_at,
        left_at: started_at + 4.hours,
      )
    end

    def companion_session(from, to, in_room: room)
      Fabricate(
        :voice_session,
        user: Fabricate(:user),
        room: in_room,
        joined_at: started_at + from,
        left_at: to && started_at + to,
      )
    end

    it "returns zero when nobody else was in the room" do
      companion_session(0.hours, 4.hours, in_room: Fabricate(:voice_room))

      expect(session.accompanied_seconds).to eq(0)
    end

    it "clips companions to the session and merges concurrent ones" do
      companion_session(-1.hour, 1.hour)
      companion_session(0.5.hours, 1.5.hours)
      companion_session(3.hours, 6.hours)

      expect(session.accompanied_seconds).to eq(2.5.hours.to_i)
    end

    it "counts a companion still in the room up to the session end" do
      freeze_time(started_at + 10.hours)
      companion_session(2.hours, nil)

      expect(session.accompanied_seconds).to eq(2.hours.to_i)
    end
  end
end
