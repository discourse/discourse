# frozen_string_literal: true

describe "Compose with a Live room hashtag" do
  fab!(:creator, :user)
  fab!(:viewer) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end
  fab!(:room) do
    Fabricate(
      :live_room,
      creator: creator,
      name: '<b id="hashtag-injected">Meeting</b>',
      slug: "meeting-room",
      public: true,
    )
  end

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
    sign_in(viewer)
  end

  it "lets the member read the room name as text in both editors" do
    page.visit("/new-topic")
    expect(composer).to be_opened
    composer.type_content("Visit ##{room.slug} ")

    expect(composer).to have_rich_hashtag(room)

    composer.toggle_rich_editor

    expect(composer).to have_preview_hashtag(room)
  end
end
