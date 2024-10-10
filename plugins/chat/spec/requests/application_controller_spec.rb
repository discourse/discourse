# frozen_string_literal: true

RSpec.describe ApplicationController do
  fab!(:user)
  fab!(:admin)

  def preloaded_json
    JSON.parse(
      Nokogiri::HTML5.fragment(response.body).css("div#data-preloaded").first["data-preloaded"],
    )
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  context "when user is admin" do
    it "has correctly loaded preloaded data for visiblePlugins" do
      sign_in(admin)
      get "/latest"
      expect(JSON.parse(preloaded_json["visiblePlugins"])).to include(
        {
          "name" => "chat",
          "admin_route" => {
            "label" => "chat.admin.title",
            "location" => "chat",
            "full_location" => "adminPlugins.show",
            "use_new_show_route" => true,
          },
          "enabled" => true,
        },
      )
    end
  end

  context "when user is not admin" do
    it "does not include preloaded data for visiblePlugins" do
      sign_in(user)
      get "/latest"
      expect(preloaded_json["visiblePlugins"]).to eq(nil)
    end
  end
end
