# frozen_string_literal: true

require_relative "page_objects/components/live_room_onebox"

describe "Live room oneboxes" do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:onebox) { PageObjects::Components::LiveRoomOnebox.new(room) }

  fab!(:user)
  fab!(:participants) { Fabricate.times(2, :user) }
  fab!(:latecomer, :user)
  fab!(:room) do
    Fabricate(:live_room, name: "Watercooler", description: "Drop in and chat", public: true)
  end
  fab!(:stage_room) do
    Fabricate(:live_room, name: "Town Hall", public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end
  # Built per example rather than with fab!, so the links use the system test
  # server's host and are recognized as local.
  let!(:post) do
    Fabricate(
      :post,
      raw:
        "#{Discourse.base_url}/live/r/#{room.slug}\n\nSee you at #{Discourse.base_url}/live/r/#{stage_room.slug} later",
    )
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"

    Jobs.run_immediately!
    post.rebake!

    participants.each { |participant| Live::ParticipantTracker.add(room.id, participant.id) }
    sign_in(user)
  end

  after { Live::ParticipantTracker.clear(room.id) }

  it "renders the room card, the inline link and who is in the room" do
    topic_page.visit_topic(post.topic)

    expect(onebox).to have_name("Watercooler")
    expect(onebox).to have_type("Live room")
    expect(onebox).to have_presence(count: 2)

    expect(page).to have_css(
      "a.inline-onebox.live-inline-onebox-stage",
      text: I18n.t("live.onebox.inline_to_room", room_name: "Town Hall"),
    )

    Live::ParticipantTracker.add(room.id, latecomer.id)
    Live::RoomBroadcaster.new(room).publish_participants

    expect(onebox).to have_presence(count: 3)
  end
end
