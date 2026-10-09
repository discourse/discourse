# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:user)

  before { SiteSetting.voice_enabled = true }

  def voice_video_available
    described_class.new(Site.new(user.guardian), scope: user.guardian, root: false).as_json[
      :voice_video_available
    ]
  end

  describe "#voice_video_available" do
    it "is true when either capability has groups" do
      SiteSetting.voice_video_allowed_groups = ""
      SiteSetting.voice_screen_share_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

      expect(voice_video_available).to eq(true)
    end

    it "is false when neither capability has groups" do
      SiteSetting.voice_video_allowed_groups = ""
      SiteSetting.voice_screen_share_allowed_groups = ""

      expect(voice_video_available).to eq(false)
    end
  end
end
