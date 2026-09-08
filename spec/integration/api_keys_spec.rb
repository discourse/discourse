# frozen_string_literal: true

RSpec.describe "api keys" do
  let(:user) { Fabricate(:user) }
  let(:api_key) { ApiKey.create!(user_id: user.id, created_by_id: Discourse.system_user) }

  it "works in headers" do
    get "/session/current.json", headers: { HTTP_API_KEY: api_key.key }
    expect(response.status).to eq(200)
    expect(response.parsed_body["current_user"]["username"]).to eq(user.username)
  end

  it "does not work in parameters" do
    get "/session/current.json", params: { api_key: api_key.key }
    expect(response.status).to eq(404)
  end

  it "does not allow overloaded requests to bypass granular API key scopes" do
    global_setting :reject_anonymous_min_queue_seconds, 1.0

    admin = Fabricate(:admin)
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic)
    scoped_api_key =
      Fabricate(
        :api_key,
        user: admin,
        api_key_scopes: [Fabricate.build(:api_key_scope, resource: "topics", action: "read")],
      )

    put "/t/#{topic.id}.json",
        params: {
          title: "This is an unauthorized title change",
        },
        headers: {
          HTTP_API_KEY: scoped_api_key.key,
          HTTP_X_REQUEST_START: "t=0",
        }

    expect(response.status).to eq(503)
    expect(response.body).to eq(
      "Server is currently experiencing high load. Please try again later.",
    )
    expect(topic.reload.title).not_to eq("This is an unauthorized title change")
  end

  it "allows parameters on ics routes" do
    get "/u/#{user.username}/bookmarks.ics?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(200)

    # Confirm not for JSON
    get "/u/#{user.username}/bookmarks.json?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(403)
  end

  it "allows parameters for handle mail" do
    admin_api_key = ApiKey.create!(user: Fabricate(:admin), created_by_id: Discourse.system_user)

    post "/admin/email/handle_mail.json?api_key=#{admin_api_key.key}", params: { email: "blah" }
    expect(response.status).to eq(200)
  end

  it "allows parameters for rss feeds" do
    SiteSetting.login_required = true

    get "/latest.rss?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(200)

    # Confirm not allowed for json
    get "/latest.json?api_key=#{api_key.key}&api_username=#{user.username.downcase}"
    expect(response.status).to eq(403)
  end

  context "with a plugin registered filter" do
    before do
      plugin = Plugin::Instance.new
      plugin.add_api_parameter_route methods: [:get], actions: ["session#current"]
    end

    it "allows parameter access to the registered route" do
      get "/session/current.json", params: { api_key: api_key.key }
      expect(response.status).to eq(200)
    end
  end
end
