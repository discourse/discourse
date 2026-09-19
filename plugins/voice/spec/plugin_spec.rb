# frozen_string_literal: true

RSpec.describe UserDestroyer do
  describe "voice cleanup" do
    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)
    fab!(:room) { Fabricate(:voice_room, creator: user, public: true) }

    before { SiteSetting.voice_enabled = true }

    it "moves the deleted user's rooms to the system user" do
      UserDestroyer.new(admin).destroy(user)

      expect(room.reload.creator_id).to eq(Discourse.system_user.id)
    end

    it "removes memberships and co-presences but keeps sessions as history" do
      session = Fabricate(:voice_session, user: user, room: room)
      ids = [user.id, other_user.id].minmax
      co_presence =
        Voice::CoPresence.create!(
          user_id_1: ids.first,
          user_id_2: ids.last,
          date: Time.zone.today,
          total_seconds: 60,
          session_count: 1,
        )

      UserDestroyer.new(admin).destroy(user)

      expect(Voice::RoomMembership.where(user_id: user.id)).to be_empty
      expect(Voice::CoPresence.exists?(co_presence.id)).to eq(false)
      expect(session.reload.user_id).to eq(user.id)
    end
  end
end
