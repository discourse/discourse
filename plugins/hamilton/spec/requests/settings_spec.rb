# frozen_string_literal: true

RSpec.describe "Hamilton settings" do
  before { enable_current_plugin }

  it "allows administrators to change the greeting" do
    sign_in(Fabricate(:admin))

    expect(SiteSetting.hamilton_greeting).to eq("world")

    put "/admin/site_settings/hamilton_greeting.json", params: { hamilton_greeting: "mcwumbly" }

    expect(response.status).to eq(204)
    expect(SiteSetting.hamilton_greeting).to eq("mcwumbly")
  end

  it "rejects anonymous changes" do
    put "/admin/site_settings/hamilton_greeting.json", params: { hamilton_greeting: "changed" }

    expect(response.status).to eq(404)
    expect(SiteSetting.hamilton_greeting).to eq("world")
  end

  it "rejects regular users and moderators" do
    [Fabricate(:user), Fabricate(:moderator)].each do |user|
      sign_in(user)

      put "/admin/site_settings/hamilton_greeting.json", params: { hamilton_greeting: "changed" }

      expect(response.status).to eq(404)
      expect(SiteSetting.hamilton_greeting).to eq("world")
    end
  end
end
