# frozen_string_literal: true

require "presence_channel"

RSpec.describe PresenceChannel do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
  fab!(:user2) { Fabricate(:user) }

  before do
    PresenceChannel.clear_all!

    secure_user = Fabricate(:user)
    secure_group = Fabricate(:group)
    PresenceChannel.register_prefix("test") do |channel|
      case channel
      when %r{\A/test/public\d*\z}
        PresenceChannel::Config.new(public: true)
      when "/test/secureuser"
        PresenceChannel::Config.new(allowed_user_ids: [secure_user.id])
      when "/test/securegroup"
        PresenceChannel::Config.new(allowed_group_ids: [secure_group.id])
      when "/test/alloweduser"
        PresenceChannel::Config.new(allowed_user_ids: [user.id])
      when "/test/allowedgroup"
        PresenceChannel::Config.new(allowed_group_ids: [group.id])
      when "/test/everyonegroup"
        PresenceChannel::Config.new(allowed_group_ids: [Group::AUTO_GROUPS[:everyone]])
      when "/test/noaccess"
        PresenceChannel::Config.new
      when "/test/countonly"
        PresenceChannel::Config.new(count_only: true, public: true)
      else
        nil
      end
    end
  end

  after do
    PresenceChannel.clear_all!
    PresenceChannel.unregister_prefix("test")
  end

  it "can perform basic channel functionality" do
    channel1 = PresenceChannel.new("/test/public1")
    channel2 = PresenceChannel.new("/test/public1")
    channel3 = PresenceChannel.new("/test/public1")

    expect(channel3.user_ids).to eq([])

    channel1.present(user_id: user.id, client_id: 1)
    channel2.present(user_id: user.id, client_id: 2)

    expect(channel3.user_ids).to eq([user.id])
    expect(channel3.count).to eq(1)

    channel1.leave(user_id: user.id, client_id: 2)

    expect(channel3.user_ids).to eq([user.id])
    expect(channel3.count).to eq(1)

    channel2.leave(user_id: user.id, client_id: 1)

    expect(channel3.user_ids).to eq([])
    expect(channel3.count).to eq(0)
  end

  it "can automatically expire users" do
    channel = PresenceChannel.new("/test/public1")

    channel.present(user_id: user.id, client_id: 76)
    channel.present(user_id: user.id, client_id: 77)

    expect(channel.count).to eq(1)

    freeze_time Time.zone.now + 1 + PresenceChannel::DEFAULT_TIMEOUT

    Jobs::PresenceChannelAutoLeave.new.execute({})

    expect(channel.count).to eq(0)
  end

  it "correctly sends messages to message bus" do
    channel = PresenceChannel.new("/test/public1")

    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.present(user_id: user.id, client_id: "a")
      end

    data = messages.map(&:data)
    expect(data.count).to eq(1)
    expect(data[0].keys).to contain_exactly("entering_users")
    expect(data[0]["entering_users"].map { |u| u[:id] }).to contain_exactly(user.id)

    freeze_time Time.zone.now + 1 + PresenceChannel::DEFAULT_TIMEOUT

    messages = MessageBus.track_publish(channel.message_bus_channel_name) { channel.auto_leave }

    data = messages.map(&:data)
    expect(data.count).to eq(1)
    expect(data[0].keys).to contain_exactly("leaving_user_ids")
    expect(data[0]["leaving_user_ids"]).to contain_exactly(user.id)
  end

  it "can track active channels, and auto_leave_all successfully" do
    channel1 = PresenceChannel.new("/test/public1")
    channel2 = PresenceChannel.new("/test/public2")

    channel1.present(user_id: user.id, client_id: "a")
    channel2.present(user_id: user.id, client_id: "a")

    start_time = Time.zone.now

    freeze_time start_time + PresenceChannel::DEFAULT_TIMEOUT / 2

    channel2.present(user_id: user2.id, client_id: "b")

    freeze_time start_time + PresenceChannel::DEFAULT_TIMEOUT + 1

    messages = MessageBus.track_publish { PresenceChannel.auto_leave_all }

    expect(messages.map { |m| [m.channel, m.data] }).to contain_exactly(
      ["/presence/test/public1", { "leaving_user_ids" => [user.id] }],
      ["/presence/test/public2", { "leaving_user_ids" => [user.id] }],
    )

    expect(channel1.user_ids).to eq([])
    expect(channel2.user_ids).to eq([user2.id])
  end

  it "only sends one `enter` and `leave` message" do
    channel = PresenceChannel.new("/test/public1")

    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.present(user_id: user.id, client_id: "a")
        channel.present(user_id: user.id, client_id: "a")
        channel.present(user_id: user.id, client_id: "b")
      end

    data = messages.map(&:data)
    expect(data.count).to eq(1)
    expect(data[0].keys).to contain_exactly("entering_users")
    expect(data[0]["entering_users"].map { |u| u[:id] }).to contain_exactly(user.id)

    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.leave(user_id: user.id, client_id: "a")
        channel.leave(user_id: user.id, client_id: "a")
        channel.leave(user_id: user.id, client_id: "b")
      end

    data = messages.map(&:data)
    expect(data.count).to eq(1)
    expect(data[0].keys).to contain_exactly("leaving_user_ids")
    expect(data[0]["leaving_user_ids"]).to contain_exactly(user.id)
  end

  it "will return the messagebus last_id in the state payload" do
    channel = PresenceChannel.new("/test/public1")

    channel.present(user_id: user.id, client_id: "a")
    channel.present(user_id: user2.id, client_id: "a")

    state = channel.state
    expect(state.user_ids).to contain_exactly(user.id, user2.id)
    expect(state.count).to eq(2)
    expect(state.message_bus_last_id).to eq(MessageBus.last_id(channel.message_bus_channel_name))
  end

  it "sets an expiry on all channel-specific keys" do
    r = Discourse.redis.without_namespace
    channel = PresenceChannel.new("/test/public1")
    channel.present(user_id: user.id, client_id: "a")

    channels_ttl = r.ttl(PresenceChannel.redis_key_channel_list)
    expect(channels_ttl).to eq(-1) # Persistent

    initial_zlist_ttl = r.ttl(channel.send(:redis_key_zlist))
    initial_hash_ttl = r.ttl(channel.send(:redis_key_hash))

    expect(initial_zlist_ttl).to be_between(
      PresenceChannel::GC_SECONDS,
      PresenceChannel::GC_SECONDS + 5.minutes,
    )
    expect(initial_hash_ttl).to be_between(
      PresenceChannel::GC_SECONDS,
      PresenceChannel::GC_SECONDS + 5.minutes,
    )

    freeze_time 1.minute.from_now

    # PresenceChannel#present is responsible for bumping ttl
    channel.present(user_id: user.id, client_id: "a")

    new_zlist_ttl = r.ttl(channel.send(:redis_key_zlist))
    new_hash_ttl = r.ttl(channel.send(:redis_key_hash))

    expect(new_zlist_ttl).to be > initial_zlist_ttl
    expect(new_hash_ttl).to be > initial_hash_ttl
  end

  it "handles security correctly for anon" do
    expect(PresenceChannel.new("/test/public1").can_enter?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/secureuser").can_enter?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/securegroup").can_enter?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/noaccess").can_enter?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/everyonegroup").can_enter?(user_id: nil)).to eq(false)

    expect(PresenceChannel.new("/test/public1").can_view?(user_id: nil)).to eq(true)
    expect(PresenceChannel.new("/test/secureuser").can_view?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/securegroup").can_view?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/noaccess").can_view?(user_id: nil)).to eq(false)
    expect(PresenceChannel.new("/test/everyonegroup").can_view?(user_id: nil)).to eq(false)
  end

  it "handles security correctly for a user" do
    expect(PresenceChannel.new("/test/secureuser").can_enter?(user_id: user.id)).to eq(false)
    expect(PresenceChannel.new("/test/securegroup").can_enter?(user_id: user.id)).to eq(false)
    expect(PresenceChannel.new("/test/alloweduser").can_enter?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/allowedgroup").can_enter?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/everyonegroup").can_enter?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/noaccess").can_enter?(user_id: user.id)).to eq(false)

    expect(PresenceChannel.new("/test/secureuser").can_view?(user_id: user.id)).to eq(false)
    expect(PresenceChannel.new("/test/securegroup").can_view?(user_id: user.id)).to eq(false)
    expect(PresenceChannel.new("/test/alloweduser").can_view?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/allowedgroup").can_view?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/everyonegroup").can_view?(user_id: user.id)).to eq(true)
    expect(PresenceChannel.new("/test/noaccess").can_view?(user_id: user.id)).to eq(false)
  end

  it "publishes messages with appropriate security" do
    channel = PresenceChannel.new("/test/alloweduser")
    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.present(user_id: user.id, client_id: "a")
      end
    expect(messages.count).to eq(1)
    expect(messages[0].user_ids).to eq([user.id])

    channel = PresenceChannel.new("/test/allowedgroup")
    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.present(user_id: user.id, client_id: "a")
      end
    expect(messages.count).to eq(1)
    expect(messages[0].group_ids).to eq([group.id])
  end

  it "publishes messages correctly in count_only mode" do
    channel = PresenceChannel.new("/test/countonly")
    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.present(user_id: user.id, client_id: "a")
      end
    expect(messages.count).to eq(1)
    expect(messages[0].data).to eq({ "count_delta" => 1 })

    messages =
      MessageBus.track_publish(channel.message_bus_channel_name) do
        channel.leave(user_id: user.id, client_id: "a")
      end
    expect(messages.count).to eq(1)
    expect(messages[0].data).to eq({ "count_delta" => -1 })
  end

  it "sets a mutex when the change involves publishing messages" do
    channel = PresenceChannel.new("/test/public1")

    messages_published = 0
    channel.define_singleton_method(:publish_message) do |*args, **kwargs|
      val = PresenceChannel.redis.get(redis_key_mutex)
      raise "Mutex was not set" if val.nil?
      messages_published += 1
    end

    redis_key_mutex = Discourse.redis.namespace_key("_presence_/test/public1_mutex")

    # Enter and leave
    expect(PresenceChannel.redis.get(redis_key_mutex)).to eq(nil)
    channel.present(user_id: user.id, client_id: "a")
    expect(PresenceChannel.redis.get(redis_key_mutex)).to eq(nil)
    channel.leave(user_id: user.id, client_id: "a")
    expect(PresenceChannel.redis.get(redis_key_mutex)).to eq(nil)
    expect(messages_published).to eq(2)

    # Enter and auto_leave
    channel.present(user_id: user.id, client_id: "a")
    expect(PresenceChannel.redis.get(redis_key_mutex)).to eq(nil)
    freeze_time 1.hour.from_now
    channel.auto_leave
    expect(PresenceChannel.redis.get(redis_key_mutex)).to eq(nil)

    expect(messages_published).to eq(4)
  end
end
