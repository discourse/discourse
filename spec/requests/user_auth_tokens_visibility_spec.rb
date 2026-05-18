# frozen_string_literal: true

require "discourse_ip_info"

RSpec.describe UsersController do
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  describe "#show" do
    before do
      sign_in(moderator)
      SiteSetting.moderators_view_ips = false
      DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb"))
    end

    it "does not expose auth token IP addresses to moderators when moderators_view_ips is disabled" do
      UserAuthToken.generate!(user_id: user.id, client_ip: "81.2.69.142", user_agent: "Mozilla/5.0")

      get "/u/#{user.username}.json"

      expect(response.status).to eq(200)

      serialized_token = response.parsed_body.dig("user", "user_auth_tokens", 0)
      expect(serialized_token.keys).not_to include("client_ip")
      expect(serialized_token["location"]).to eq("London, England, United Kingdom")
      expect(response.body).not_to include('"client_ip"')
      expect(response.body).not_to include("81.2.69.142")
    end
  end
end
