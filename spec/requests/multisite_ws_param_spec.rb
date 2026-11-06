# frozen_string_literal: true

RSpec.describe "Site selection with the __ws param", type: %i[multisite request] do
  after { RailsMultisite::ConnectionManagement.asset_hostnames = nil }

  it "ignores __ws on a site's own hostname" do
    user = Fabricate(:user)
    RailsMultisite::ConnectionManagement.asset_hostnames = GlobalSetting.cdn_hostnames

    get "/u/#{user.username}.json", params: { __ws: "test2.localhost" }

    expect(response.status).to eq(200)
  end

  it "selects the site named by __ws on a CDN hostname" do
    global_setting :cdn_url, "https://cdn.example.com"
    RailsMultisite::ConnectionManagement.asset_hostnames = GlobalSetting.cdn_hostnames
    host! "cdn.example.com"

    test_multisite_connection("second") do
      user = Fabricate(:user)

      get "/u/#{user.username}.json", params: { __ws: "test2.localhost" }

      expect(response.status).to eq(200)
    end
  end
end
