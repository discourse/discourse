# frozen_string_literal: true

RSpec.describe Voice::RoomSerializer do
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  def serialize(scope)
    described_class.new(room, scope: scope, root: false).as_json
  end

  describe "media publish rights" do
    it "reports each capability separately" do
      SiteSetting.voice_screen_share_allowed_groups = ""

      payload = serialize(user.guardian)

      expect(payload[:video_allowed]).to eq(true)
      expect(payload[:screen_share_allowed]).to eq(false)
    end

    # Directory broadcasts are serialized without a user; sending them as
    # false would revoke every client's own rights on an unrelated update.
    it "omits both for an anonymous scope, leaving the room's own flag" do
      payload = serialize(Guardian.new(nil))

      expect(payload).not_to have_key(:video_allowed)
      expect(payload).not_to have_key(:screen_share_allowed)
      expect(payload[:video_enabled]).to eq(true)
    end
  end
end
