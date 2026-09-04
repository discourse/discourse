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

  describe "roster media entitlements" do
    fab!(:speaker, :user)

    before do
      Voice::ParticipantTracker.add(room.id, user.id)
      Voice::ParticipantTracker.add(room.id, speaker.id)
    end

    # Mesh receivers decide what to play from the sender's entry, so every
    # participant carries its own entitlements — including in the
    # anonymously-scoped broadcasts.
    it "stamps each participant with their own capabilities" do
      SiteSetting.voice_screen_share_allowed_groups = ""

      participants = serialize(Guardian.new(nil))[:active_participants]

      expect(participants.size).to eq(2)
      expect(participants.map { |p| p[:can_publish_video] }).to all(eq(true))
      expect(participants.map { |p| p[:can_screen_share] }).to all(eq(false))
    end

    it "stamps nothing when the room has media disabled" do
      room.update!(video_enabled: false)

      participants = serialize(user.guardian)[:active_participants]

      expect(participants.map { |p| p[:can_publish_video] }).to all(eq(false))
      expect(participants.map { |p| p[:can_screen_share] }).to all(eq(false))
    end
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
