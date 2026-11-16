# frozen_string_literal: true

RSpec.describe UserDestroyer do
  describe "live cleanup" do
    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)
    fab!(:room) { Fabricate(:live_room, creator: user, public: true) }

    before { SiteSetting.live_enabled = true }

    it "moves the deleted user's rooms to the system user" do
      UserDestroyer.new(admin).destroy(user)

      expect(room.reload.creator_id).to eq(Discourse.system_user.id)
    end

    it "removes memberships and co-presences but keeps sessions as history" do
      session = Fabricate(:live_session, user: user, room: room)
      ids = [user.id, other_user.id].minmax
      co_presence =
        Live::CoPresence.create!(
          user_id_1: ids.first,
          user_id_2: ids.last,
          date: Time.zone.today,
          total_seconds: 60,
          session_count: 1,
        )

      UserDestroyer.new(admin).destroy(user)

      expect(Live::RoomMembership.where(user_id: user.id)).to be_empty
      expect(Live::CoPresence.exists?(co_presence.id)).to eq(false)
      expect(session.reload.user_id).to eq(user.id)
    end
  end
end
