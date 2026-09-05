# frozen_string_literal: true

RSpec.describe Voice::RoomBroadcaster do
  fab!(:participant, :user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before { SiteSetting.voice_enabled = true }

  describe ".publish_participants" do
    it "reaches anonymous subscribers through the anonymous_users pseudogroup when they are admitted" do
      SiteSetting.voice_allowed_groups =
        "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
      Voice::ParticipantTracker.add(room.id, participant.id)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.publish_participants(room)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.group_ids).to contain_exactly(
        Group::AUTO_GROUPS[:anonymous_users],
        Group::AUTO_GROUPS[:logged_in_users],
      )

      anonymous_client =
        MessageBus::Client.new(
          client_id: "anonymous",
          user_id: nil,
          group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
        )
      expect(anonymous_client.allowed?(messages.first)).to eq(true)
    end

    it "targets logged-in subscribers, never anonymous ones, when allowed groups are logged_in_users" do
      SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
      Voice::ParticipantTracker.add(room.id, participant.id)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.publish_participants(room)
        end

      expect(messages.first.group_ids).to contain_exactly(Group::AUTO_GROUPS[:logged_in_users])

      anonymous_client =
        MessageBus::Client.new(
          client_id: "anonymous",
          user_id: nil,
          group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
        )
      expect(anonymous_client.allowed?(messages.first)).to eq(false)
    end

    it "targets allowed groups plus current participants when access is restricted" do
      group = Fabricate(:group)
      SiteSetting.voice_allowed_groups = group.id.to_s
      Voice::ParticipantTracker.add(room.id, participant.id)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.publish_participants(room)
        end

      expect(messages.first.group_ids).to contain_exactly(group.id)
      expect(messages.first.user_ids).to contain_exactly(participant.id)
    end

    it "targets members plus current participants for private rooms" do
      private_room = Fabricate(:voice_room, public: false)
      Voice::ParticipantTracker.add(private_room.id, participant.id)

      messages =
        MessageBus.track_publish(Voice.room_channel(private_room.id)) do
          described_class.publish_participants(private_room)
        end

      expect(messages.first.user_ids).to contain_exactly(private_room.creator_id, participant.id)
    end
  end

  describe ".publish_hand_raise" do
    fab!(:second_participant, :user)

    it "publishes the hand event to exactly the tracked participants" do
      Voice::ParticipantTracker.add(room.id, participant.id)
      Voice::ParticipantTracker.add(room.id, second_participant.id)
      raised_at = Time.now.to_f

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.publish_hand_raise(
            room,
            participant.id,
            raised: true,
            raised_at: raised_at,
            reason: "raised",
          )
        end

      expect(messages.size).to eq(1)
      message = messages.first
      expect(message.user_ids).to contain_exactly(participant.id, second_participant.id)
      expect(message.data).to eq(
        type: "hand_raise",
        room_id: room.id,
        user_id: participant.id,
        raised: true,
        raised_at: raised_at,
        reason: "raised",
      )
    end

    it "does not publish when the room has no participants" do
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.publish_hand_raise(
            room,
            participant.id,
            raised: false,
            reason: "withdrawn",
          )
        end

      expect(messages).to be_empty
    end
  end
end
