# frozen_string_literal: true

RSpec.describe PresenceController do
  fab!(:user)
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }

  let(:ch1) { PresenceChannel.new("/test/public1") }
  let(:ch2) { PresenceChannel.new("/test/public2") }

  let(:secure_user_channel) { PresenceChannel.new("/test/secureuser") }
  let(:secure_group_channel) { PresenceChannel.new("/test/securegroup") }
  let(:allowed_user_channel) { PresenceChannel.new("/test/alloweduser") }
  let(:allowed_group_channel) { PresenceChannel.new("/test/allowedgroup") }
  let(:count_only_channel) { PresenceChannel.new("/test/countonly") }

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
      when "/test/countonly"
        PresenceChannel::Config.new(public: true, count_only: true)
      else
        nil
      end
    end
  end

  after do
    PresenceChannel.clear_all!
    PresenceChannel.unregister_prefix("test")
  end

  describe "#update" do
    context "in readonly mode" do
      before { Discourse.enable_readonly_mode }

      it "produces 503" do
        sign_in(user)
        client_id = SecureRandom.hex

        post "/presence/update.json",
             params: {
               client_id: client_id,
               present_channels: [ch1.name, ch2.name],
             }

        expect(response.status).to eq(503)
      end
    end

    it "works" do
      sign_in(user)
      client_id = SecureRandom.hex

      expect(ch1.user_ids).to eq([])
      expect(ch2.user_ids).to eq([])

      post "/presence/update.json",
           params: {
             client_id: client_id,
             present_channels: [ch1.name, ch2.name],
           }
      expect(response.status).to eq(200)
      expect(ch1.user_ids).to eq([user.id])
      expect(ch2.user_ids).to eq([user.id])

      post "/presence/update.json",
           params: {
             client_id: client_id,
             present_channels: [ch1.name],
             leave_channels: [ch2.name],
           }
      expect(response.status).to eq(200)
      expect(ch1.user_ids).to eq([user.id])
      expect(ch2.user_ids).to eq([])

      post "/presence/update.json",
           params: {
             client_id: client_id,
             present_channels: [],
             leave_channels: [ch1.name],
           }
      expect(response.status).to eq(200)
      expect(ch1.user_ids).to eq([])
      expect(ch2.user_ids).to eq([])
    end

    it "returns true/false based on channel existence/security" do
      sign_in(user)
      client_id = SecureRandom.hex

      expect(ch1.user_ids).to eq([])
      expect(secure_user_channel.user_ids).to eq([])
      expect(secure_group_channel.user_ids).to eq([])

      post "/presence/update.json",
           params: {
             client_id: client_id,
             present_channels: [
               ch1.name,
               secure_user_channel.name,
               secure_group_channel.name,
               allowed_user_channel.name,
               allowed_group_channel.name,
               "/test/nonexistent",
             ],
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        {
          ch1.name => true,
          secure_user_channel.name => false,
          secure_group_channel.name => false,
          allowed_user_channel.name => true,
          allowed_group_channel.name => true,
          "/test/nonexistent" => false,
        },
      )

      expect(ch1.user_ids).to eq([user.id])
      expect(secure_user_channel.user_ids).to eq([])
      expect(secure_group_channel.user_ids).to eq([])
      expect(allowed_user_channel.user_ids).to eq([user.id])
      expect(allowed_group_channel.user_ids).to eq([user.id])
    end

    it "doesn't overwrite the session" do
      sign_in(user)

      session_cookie_name = "_forum_session"
      get "/session/csrf.json"
      expect(response.status).to eq(200)
      expect(response.cookies.keys).to include(session_cookie_name)

      client_id = SecureRandom.hex
      post "/presence/update.json", params: { client_id: client_id, present_channels: [ch1.name] }
      expect(response.status).to eq(200)
      expect(response.cookies.keys).not_to include(session_cookie_name)
    end
  end

  describe "#get" do
    let(:user2) { Fabricate(:user) }
    let(:user3) { Fabricate(:user) }

    it "works" do
      get "/presence/get", params: { channels: [ch1.name] }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        ch1.name => {
          "users" => [],
          "count" => 0,
          "last_message_id" => MessageBus.last_id(ch1.message_bus_channel_name),
        },
      )

      ch1.present(user_id: user.id, client_id: SecureRandom.hex)
      ch1.present(user_id: user2.id, client_id: SecureRandom.hex)
      ch1.present(user_id: user3.id, client_id: SecureRandom.hex)

      get "/presence/get", params: { channels: [ch1.name] }
      expect(response.status).to eq(200)
      state = response.parsed_body[ch1.name]
      expect(state["users"].map { |u| u["id"] }).to contain_exactly(user.id, user2.id, user3.id)
      expect(state["users"][0].keys).to contain_exactly("avatar_template", "id", "name", "username")
      expect(state["count"]).to eq(3)
      expect(state["last_message_id"]).to eq(MessageBus.last_id(ch1.message_bus_channel_name))
    end

    it "respects the existence/security of the channel" do
      sign_in user

      get "/presence/get",
          params: {
            channels: [
              ch1.name,
              allowed_user_channel.name,
              allowed_group_channel.name,
              secure_user_channel.name,
              secure_group_channel.name,
              "/test/nonexistent",
            ],
          }

      expect(response.status).to eq(200)

      expect(response.parsed_body).to include(
        ch1.name => be_truthy,
        allowed_user_channel.name => be_truthy,
        allowed_group_channel.name => be_truthy,
        secure_user_channel.name => be_nil,
        secure_group_channel.name => be_nil,
        "/test/nonexistent" => be_nil,
      )
    end

    it "works for count_only channels" do
      get "/presence/get", params: { channels: [count_only_channel.name] }
      expect(response.status).to eq(200)
      state = response.parsed_body[count_only_channel.name]
      expect(state.keys).to contain_exactly("count", "last_message_id")
      expect(state["count"]).to eq(0)

      count_only_channel.present(user_id: user.id, client_id: "a")

      get "/presence/get", params: { channels: [count_only_channel.name] }
      expect(response.status).to eq(200)
      expect(response.parsed_body[count_only_channel.name]["count"]).to eq(1)
    end
  end
end
