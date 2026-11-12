# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:user)

  before { SiteSetting.live_enabled = true }

  def live_video_available
    described_class.new(Site.new(user.guardian), scope: user.guardian, root: false).as_json[
      :live_video_available
    ]
  end

  describe "#live_video_available" do
    it "is true when either capability has groups" do
      SiteSetting.live_video_allowed_groups = ""
      SiteSetting.live_screen_share_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

      expect(live_video_available).to eq(true)
    end

    it "is false when neither capability has groups" do
      SiteSetting.live_video_allowed_groups = ""
      SiteSetting.live_screen_share_allowed_groups = ""

      expect(live_video_available).to eq(false)
    end
  end
end
