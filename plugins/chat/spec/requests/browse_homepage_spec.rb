# frozen_string_literal: true

RSpec.describe "Chat channel directory homepage" do
  fab!(:chatters, :group)
  fab!(:user) { Fabricate(:user, group_ids: [chatters.id], refresh_auto_groups: true) }

  let(:crawler_request) { ActionDispatch::TestRequest.create("HTTP_USER_AGENT" => "Googlebot") }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = chatters.id
    SiteSetting.top_menu = "latest|new|top|categories"
    SiteSetting.default_homepage = "chat_browse"
  end

  it "resolves to the channel directory" do
    expect(HomepageHelper.resolve(nil, user)).to eq("chat_browse")
  end

  it "points the homepage at open channels" do
    serialized = SiteSerializer.new(Site.new(user.guardian), scope: user.guardian, root: false)

    expect(serialized.as_json[:homepage_options]).to include(
      id: "chat_browse",
      path: "/chat/browse/open",
      server_side: false,
    )
  end

  it "renders the app at the root path" do
    SiteSetting.has_login_hint = false
    sign_in(user)

    get "/"

    expect(response.status).to eq(200)
    expect(response.body).to include(
      '<meta name="discourse_current_homepage" content="chat_browse">',
    )
  end

  it "is not offered as a homepage choice when public channels are disabled" do
    expect(HomepageSiteSetting.choices).to include("chat_browse")

    SiteSetting.enable_public_channels = false

    expect(HomepageSiteSetting.choices).not_to include("chat_browse")
    expect(HomepageHelper.resolve(nil, user)).to eq("latest")
  end

  it "falls back when chat is disabled" do
    SiteSetting.chat_enabled = false

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

  it "falls back for crawlers" do
    expect(HomepageHelper.resolve(crawler_request, user)).to eq("latest")
  end

  it "falls back for anonymous visitors even when anonymous chat access is allowed" do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:anonymous_users]

    expect(HomepageHelper.resolve).to eq("latest")
  end
end
