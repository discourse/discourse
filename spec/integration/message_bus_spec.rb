# frozen_string_literal: true

RSpec.describe "message bus integration" do
  it "allows anonymous requests to the messagebus" do
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows authenticated requests to the messagebus" do
    sign_in Fabricate(:user)
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows custom cors origins" do
    global_setting :enable_cors, true
    SiteSetting.cors_origins = "https://allowed.example.com"

    post "/message-bus/poll"
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)

    post "/message-bus/poll", headers: { origin: "https://allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://allowed.example.com")

    post "/message-bus/poll", headers: { origin: "https://not-allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)
  end

  context "with login_required" do
    before { SiteSetting.login_required = true }

    it "blocks anonymous requests to the messagebus" do
      post "/message-bus/poll"
      expect(response.status).to eq(403)
    end

    it "allows authenticated requests to the messagebus" do
      sign_in Fabricate(:user)
      post "/message-bus/poll"
      expect(response.status).to eq(200)
    end
  end

  describe "after a database restore" do
    it "does not replay private messages to a different user assigned the prior recipient ID" do
      previous_user = Fabricate(:user)
      restored_user = Fabricate(:user)
      private_message = { "chat_message" => { "message" => "private message before restore" } }
      channel = "/chat/user/#{previous_user.id}"
      message_id = MessageBus.publish(channel, private_message, user_ids: [previous_user.id])

      previous_user_id = previous_user.id
      previous_user.update_columns(id: User.maximum(:id) + 1)
      restored_user.update_columns(id: previous_user_id)

      BackupRestore::SystemInterface.new(nil).flush_redis
      sign_in(restored_user.reload)
      post "/message-bus/#{SecureRandom.hex}/poll?dlp=t", params: { channel => message_id - 1 }

      expect(response.status).to eq(200)
      expect(response.body).not_to include(private_message.dig("chat_message", "message"))
    end
  end
end
