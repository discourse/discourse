# frozen_string_literal: true

RSpec.describe "Chat channel homepage" do
  fab!(:chatters, :group)
  fab!(:user) { Fabricate(:user, group_ids: [chatters.id], refresh_auto_groups: true) }
  fab!(:channel_1) { Fabricate(:category_channel, name: "General") }

  let(:crawler_request) { ActionDispatch::TestRequest.create("HTTP_USER_AGENT" => "Googlebot") }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = chatters.id
    SiteSetting.top_menu = "latest|new|top|categories"
    SiteSetting.default_homepage = "chat"
    SiteSetting.chat_homepage_channel = channel_1.id
  end

  it "resolves to chat" do
    expect(HomepageHelper.resolve(nil, user)).to eq("chat")
  end

  it "points the homepage at the channel" do
    serialized = SiteSerializer.new(Site.new(user.guardian), scope: user.guardian, root: false)

    expect(serialized.as_json[:homepage_options]).to include(
      id: "chat",
      path: channel_1.relative_url,
      server_side: false,
    )
  end

  it "leaves the subfolder out of the homepage path" do
    set_subfolder "/forum"

    serialized = SiteSerializer.new(Site.new(user.guardian), scope: user.guardian, root: false)

    expect(serialized.as_json[:homepage_options]).to include(
      id: "chat",
      path: "/chat/c/#{channel_1.slug}/#{channel_1.id}",
      server_side: false,
    )
  end

  it "renders the app at the root path" do
    SiteSetting.has_login_hint = false
    sign_in(user)

    get "/"

    expect(response.status).to eq(200)
    expect(response.body).to include('<meta name="discourse_current_homepage" content="chat">')
  end

  it "is not offered as a homepage choice when public channels are disabled" do
    expect(HomepageSiteSetting.choices).to include("chat")

    SiteSetting.enable_public_channels = false

    expect(HomepageSiteSetting.choices).not_to include("chat")
    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when no channel is chosen" do
    SiteSetting.chat_homepage_channel = ""

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when chat is disabled" do
    SiteSetting.chat_enabled = false

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when the channel no longer exists" do
    channel_1.destroy!

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when the channel is archived" do
    channel_1.update!(status: :archived)

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when chat_allowed_groups excludes the user" do
    SiteSetting.chat_allowed_groups = Fabricate(:group).id

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when the user has disabled chat in their preferences" do
    user.user_option.update!(chat_enabled: false)

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when the user cannot see the channel's category" do
    channel_1.chatable.update!(read_restricted: true)

    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back for crawlers" do
    expect(HomepageHelper.resolve(crawler_request, user)).to eq("latest")
  end

  context "with an anonymous visitor" do
    it "falls back when anonymous chat access is not allowed" do
      expect(HomepageHelper.resolve).to eq("latest")
    end

    it "resolves to chat when anonymous chat access is allowed" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:anonymous_users]

      expect(HomepageHelper.resolve).to eq("chat")
    end
  end
end
