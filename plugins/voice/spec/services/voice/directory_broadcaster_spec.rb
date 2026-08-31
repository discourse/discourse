# frozen_string_literal: true

RSpec.describe Voice::DirectoryBroadcaster do
  before { SiteSetting.voice_enabled = true }

  it "publishes public room events without targets when allowed groups include everyone" do
    # With the granular flag on, a stored `everyone` reads as logged_in_users
    # and the publish is group-targeted instead (covered below).
    SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s
    room = Fabricate(:voice_room, public: true)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.size).to eq(1)
    expect(messages.first.user_ids).to be_nil
    expect(messages.first.group_ids).to be_nil
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

  it "publishes without targets when allowed groups include anonymous_users" do
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:anonymous_users].to_s
    room = Fabricate(:voice_room, public: true)

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :updated, room: room)
      end

    expect(messages.first.user_ids).to be_nil
    expect(messages.first.group_ids).to be_nil
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
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s

    messages =
      MessageBus.track_publish(Voice.room_index_channel) do
        described_class.broadcast(action: :created, room: room)
      end

    expect(messages).to be_empty
  end
end
