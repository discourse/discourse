# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::VoiceUsage do
  fab!(:user)
  fab!(:friend, :user)
  fab!(:public_room) { Fabricate(:voice_room, public: true) }
  fab!(:private_room, :voice_room)

  before { SiteSetting.voice_enabled = true }

  def fabricate_session(room:, joined_at:, duration:)
    Fabricate(:voice_session, user:, room:, joined_at:, left_at: duration && joined_at + duration)
  end

  describe ".call" do
    it "returns nothing when there is too little airtime to show" do
      fabricate_session(room: public_room, joined_at: random_datetime, duration: 10.minutes)

      expect(call_report).to be_nil
    end

    it "returns the airtime, favorite rooms and most frequent contacts" do
      fabricate_session(room: public_room, joined_at: random_datetime, duration: 2.hours)
      fabricate_session(room: private_room, joined_at: random_datetime, duration: 1.hour)
      fabricate_session(
        room: Fabricate(:voice_ephemeral_room),
        joined_at: random_datetime,
        duration: 1.hour,
      )
      fabricate_session(room: public_room, joined_at: 2.years.ago, duration: 5.hours)
      Voice::CoPresence.create!(
        user_id_1: [user.id, friend.id].min,
        user_id_2: [user.id, friend.id].max,
        date: random_datetime.to_date,
        total_seconds: 1.hour.to_i,
        session_count: 1,
      )

      expect(call_report[:data]).to eq(
        total_seconds: 4.hours.to_i,
        call_count: 3,
        top_rooms: [
          {
            room_id: public_room.id,
            name: public_room.name,
            slug: public_room.slug,
            seconds: 2.hours.to_i,
          },
          {
            room_id: private_room.id,
            name: private_room.name,
            slug: private_room.slug,
            seconds: 1.hour.to_i,
          },
        ],
        top_contacts: [
          { user: BasicUserSerializer.new(friend, root: false).as_json, seconds: 1.hour.to_i },
        ],
      )
    end

    it "caps sessions that never ended" do
      fabricate_session(room: public_room, joined_at: random_datetime, duration: 1.hour)
      fabricate_session(room: public_room, joined_at: random_datetime, duration: nil)

      expect(call_report[:data][:total_seconds]).to eq(90.minutes.to_i)
    end
  end

  describe ".filter_for_viewer" do
    let(:report) do
      {
        data: {
          top_rooms: [public_room, private_room].map { |room| { room_id: room.id } },
          top_contacts: [{ user: { id: friend.id }, seconds: 1 }],
        },
      }
    end

    it "keeps everything the owner can see" do
      private_room.room_memberships.create!(user:)

      filtered = described_class.filter_for_viewer(report, guardian: user.guardian, for_user: user)

      expect(filtered).to eq(report)
    end

    it "hides contacts and rooms other viewers cannot see" do
      filtered =
        described_class.filter_for_viewer(
          report,
          guardian: Fabricate(:user).guardian,
          for_user: user,
        )

      expect(filtered[:data]).to eq(top_rooms: [{ room_id: public_room.id }], top_contacts: [])
    end
  end
end
