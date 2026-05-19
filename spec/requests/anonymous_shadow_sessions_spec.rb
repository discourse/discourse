# frozen_string_literal: true

RSpec.describe "Anonymous shadow sessions" do
  fab!(:admin)
  fab!(:master_user) { Fabricate(:user, trust_level: TrustLevel[3]) }

  before do
    SiteSetting.allow_anonymous_mode = true
    SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  it "stops authenticating when the master account is suspended" do
    shadow_user = AnonymousShadowCreator.get(master_user)
    sign_in(shadow_user)

    get "/session/current.json"
    expect(response.status).to eq(200)

    UserSuspender.new(
      master_user,
      suspended_till: 1.day.from_now,
      reason: "spam",
      by_user: admin,
    ).suspend

    get "/session/current.json"

    expect(response.status).to eq(404)
    expect(response.body).to be_blank
  end

  it "stops authenticating when the master account is deactivated" do
    shadow_user = AnonymousShadowCreator.get(master_user)
    sign_in(shadow_user)

    get "/session/current.json"
    expect(response.status).to eq(200)

    master_user.deactivate(admin)

    get "/session/current.json"

    expect(response.status).to eq(404)
    expect(response.body).to be_blank
  end
end
