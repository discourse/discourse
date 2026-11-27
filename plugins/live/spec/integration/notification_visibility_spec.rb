# frozen_string_literal: true

RSpec.describe "Live notification visibility" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:room, :live_room)
  fab!(:invitation) do
    Fabricate(
      :notification,
      user:,
      topic: nil,
      notification_type: Notification.types[:live_invitation],
      data: { room_id: room.id, room_name: room.name }.to_json,
    )
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    room.room_memberships.create!(user:, role: Live::RoomMembership::ROLE_PARTICIPANT)
  end

  def visible_notifications
    Notification::Feed.new(User.find(user.id)).notifications
  end

  it "shows an invitation to a member of the room" do
    expect(visible_notifications).to contain_exactly(invitation)
  end

  it "shows a call into a temporary room" do
    call_room = Fabricate(:live_ephemeral_room, public: true)
    invitation.update!(data: { room_id: call_room.id }.to_json)

    expect(visible_notifications).to contain_exactly(invitation)
  end

  it "hides an invitation when the user is removed from the room" do
    room.room_memberships.destroy_all

    expect(visible_notifications).to be_empty
  end

  it "hides an invitation when its room is deleted" do
    room.destroy!

    expect(visible_notifications).to be_empty
  end

  it "hides an invitation when the user loses access to live" do
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:staff]

    expect(visible_notifications).to be_empty
  end

  it "hides an invitation when live is disabled" do
    SiteSetting.live_enabled = false

    expect(visible_notifications).to be_empty
  end
end
