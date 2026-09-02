# frozen_string_literal: true

RSpec.describe Voice::EphemeralRoomManager do
  fab!(:creator, :user)
  fab!(:member, :user)

  before { SiteSetting.voice_enabled = true }

  describe ".create!" do
    it "creates an ephemeral room with the creator as moderator and members as participants" do
      room = described_class.create!(creator: creator, name: "Call", members: [member, creator])

      expect(room.ephemeral).to eq(true)
      expect(room.public).to eq(false)
      expect(room.last_occupied_at).to be_present
      expect(room.room_memberships.moderator.pluck(:user_id)).to contain_exactly(creator.id)
      expect(room.member_ids).to contain_exactly(creator.id, member.id)
    end

    it "generates slugs that never collide with existing rooms of the same name" do
      persistent = Fabricate(:voice_room, name: "Call")
      first = described_class.create!(creator: creator, name: "Call")
      second = described_class.create!(creator: creator, name: "Call")

      expect([persistent.slug, first.slug, second.slug].uniq.size).to eq(3)
      expect(first.slug).to start_with("call-")
    end

    it "makes all parties moderators when passed as such, so any of them can invite" do
      room = described_class.create!(creator: creator, name: "Call", moderators: [member, creator])

      expect(room.moderator_ids).to contain_exactly(creator.id, member.id)
      expect(member.guardian.can_manage_voice_room?(room)).to eq(true)
    end

    it "keeps the moderator role for a user listed as both moderator and member" do
      room =
        described_class.create!(
          creator: creator,
          name: "Call",
          members: [member],
          moderators: [member],
        )

      expect(room.moderator_ids).to contain_exactly(creator.id, member.id)
    end

    it "caps how many live ephemeral rooms one creator can accumulate" do
      stub_const(described_class, :MAX_LIVE_ROOMS_PER_CREATOR, 2) do
        2.times { |i| described_class.create!(creator: creator, name: "Call #{i}") }

        expect { described_class.create!(creator: creator, name: "One too many") }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect(Voice::Room.ephemeral.where(creator_id: creator.id).count).to eq(2)
      end
    end

    it "does not count other creators' rooms against the cap" do
      stub_const(described_class, :MAX_LIVE_ROOMS_PER_CREATOR, 1) do
        described_class.create!(creator: member, name: "Someone else's call")

        expect(described_class.create!(creator: creator, name: "Call")).to be_persisted
      end
    end

    it "passes room attributes through" do
      room =
        described_class.create!(
          creator: creator,
          name: "Event stage",
          public: true,
          room_type: Voice::Room::ROOM_TYPE_STAGE,
        )

      expect(room.public).to eq(true)
      expect(room.stage?).to eq(true)
    end

    it "does not broadcast a directory event" do
      messages =
        MessageBus.track_publish(Voice.room_index_channel) do
          described_class.create!(creator: creator, name: "Call", members: [member])
        end

      expect(messages).to be_empty
    end
  end

  describe ".cleanup!" do
    fab!(:persistent_room, :voice_room)

    before { SiteSetting.voice_ephemeral_room_ttl_minutes = 30 }

    it "destroys an ephemeral room empty past the TTL and clears its live state" do
      room = Fabricate(:voice_ephemeral_room, last_occupied_at: 31.minutes.ago)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

      described_class.cleanup!

      expect(Voice::Room.exists?(room.id)).to eq(false)
      expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
    end

    it "uses created_at when the room was never occupied" do
      room = Fabricate(:voice_ephemeral_room, last_occupied_at: nil, created_at: 31.minutes.ago)

      described_class.cleanup!

      expect(Voice::Room.exists?(room.id)).to eq(false)
    end

    it "keeps an ephemeral room emptied more recently than the TTL" do
      room = Fabricate(:voice_ephemeral_room, last_occupied_at: 5.minutes.ago)

      described_class.cleanup!

      expect(Voice::Room.exists?(room.id)).to eq(true)
    end

    it "resets the clock on an occupied ephemeral room instead of destroying it" do
      room = Fabricate(:voice_ephemeral_room, last_occupied_at: 31.minutes.ago)
      Voice::ParticipantTracker.add(room.id, Fabricate(:user).id)

      described_class.cleanup!

      expect(room.reload.last_occupied_at).to be_within(1.minute).of(Time.current)
    end

    it "never touches persistent rooms" do
      persistent_room.update_column(:last_occupied_at, 2.days.ago)

      expect { described_class.cleanup! }.not_to change { Voice::Room.persistent.count }
    end
  end

  describe ".destroy!" do
    it "refuses to tear down a persistent room" do
      room = Fabricate(:voice_room)

      expect { described_class.destroy!(room) }.to raise_error(Discourse::InvalidParameters)
      expect(Voice::Room.exists?(room.id)).to eq(true)
    end
  end
end
