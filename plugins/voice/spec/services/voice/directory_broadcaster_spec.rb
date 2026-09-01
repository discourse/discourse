# frozen_string_literal: true

RSpec.describe Voice::DirectoryBroadcaster do
  before { SiteSetting.voice_enabled = true }

  it "reaches anonymous subscribers through the anonymous_users pseudogroup when they are admitted" do
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    room = Fabricate(:voice_room, public: true)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.size).to eq(1)
    expect(messages.first.group_ids).to contain_exactly(
      Group::AUTO_GROUPS[:anonymous_users],
      Group::AUTO_GROUPS[:logged_in_users],
    )

    # Anonymous message-bus clients carry only the anonymous_users
    # pseudo-group (see config/initializers/004-message_bus.rb).
    anonymous_client =
      MessageBus::Client.new(
        client_id: "anonymous",
        user_id: nil,
        group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )
    expect(anonymous_client.allowed?(messages.first)).to eq(true)
  end

  it "excludes anonymous subscribers when allowed groups are logged_in_users" do
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
    room = Fabricate(:voice_room, public: true)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.size).to eq(1)
    expect(messages.first.group_ids).to contain_exactly(Group::AUTO_GROUPS[:logged_in_users])

    # Subscriber-level check with the group ids real clients get from
    # config/initializers/004-message_bus.rb: logged-in clients carry the
    # logged_in_users pseudo-group, anonymous clients only anonymous_users.
    logged_in_client =
      MessageBus::Client.new(
        client_id: "logged-in",
        user_id: room.creator_id,
        group_ids: [Group::AUTO_GROUPS[:logged_in_users]],
      )
    anonymous_client =
      MessageBus::Client.new(
        client_id: "anonymous",
        user_id: nil,
        group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )

    expect(logged_in_client.allowed?(messages.first)).to eq(true)
    expect(anonymous_client.allowed?(messages.first)).to eq(false)
  end

  it "targets the anonymous_users pseudogroup when only anonymous access is configured" do
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:anonymous_users].to_s
    room = Fabricate(:voice_room, public: true)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.first.user_ids).to be_nil
    expect(messages.first.group_ids).to contain_exactly(Group::AUTO_GROUPS[:anonymous_users])
  end

  it "targets members for private room events" do
    room = Fabricate(:voice_room, public: false)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.first.user_ids).to contain_exactly(room.creator_id)
  end

  it "never publishes events for ephemeral rooms" do
    room = Fabricate(:voice_ephemeral_room, public: true)
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :created, room: room)
      end

    expect(messages).to be_empty
  end
end
