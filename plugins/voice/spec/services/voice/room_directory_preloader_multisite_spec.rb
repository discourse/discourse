# frozen_string_literal: true

RSpec.describe Voice::RoomDirectoryPreloader, type: :multisite do
  let(:room_id) { 9_000_000 + SecureRandom.random_number(100_000) }

  after do
    %w[default second].each do |site|
      RailsMultisite::ConnectionManagement.with_connection(site) do
        Voice::ParticipantTracker.clear(room_id)
      end
    end
  end

  it "keeps batched Redis and MessageBus room state isolated by site" do
    channel = Voice.room_channel(room_id)
    Voice::ParticipantTracker.add(room_id, 101)
    Voice::ParticipantTracker.update_metadata(room_id, 101, muted: true)
    Voice::ParticipantTracker.pin_transport!(room_id, "mesh")
    default_message_id = MessageBus.publish(channel, type: "participants")

    test_multisite_connection("second") do
      second_state = Voice::ParticipantTracker.room_states([room_id]).fetch(room_id)

      expect(second_state.participant_ids).to be_empty
      expect(second_state.participant_metadata).to be_empty
      expect(second_state.pinned_transport).to be_nil
      expect(MessageBus.last_ids(channel).fetch(channel)).to eq(0)

      Voice::ParticipantTracker.add(room_id, 202)
      Voice::ParticipantTracker.pin_transport!(room_id, "livekit")
      MessageBus.publish(channel, type: "participants")
    end

    default_state = Voice::ParticipantTracker.room_states([room_id]).fetch(room_id)
    expect(default_state.participant_ids).to eq([101])
    expect(default_state.participant_metadata).to eq(101 => { muted: true })
    expect(default_state.pinned_transport).to eq("mesh")
    expect(MessageBus.last_ids(channel).fetch(channel)).to eq(default_message_id)
  end
end
