# frozen_string_literal: true

describe "Live room hashtags in the composer" do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:room) do
    Fabricate(
      :live_room,
      creator: user,
      name: '<b id="hashtag-injected">Meeting</b>',
      slug: "meeting-room",
      public: true,
    )
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
    sign_in(user)
  end

  it "displays the room name as text in the markdown preview" do
    topic_page.visit_topic_and_open_composer(topic)
    composer.fill_content("Visit ##{room.slug} for the meeting")

    expect(composer.preview).to have_css("a.hashtag-cooked", text: room.name)
    expect(composer.preview).to have_no_css("#hashtag-injected")
  end

  it "displays the room name as text in the rich editor" do
    user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    topic_page.visit_topic_and_open_composer(topic)
    composer.type_content("Visit ##{room.slug} ")

    expect(composer.rich_editor).to have_css("a.hashtag-cooked", text: room.name)
    expect(composer.rich_editor).to have_no_css("#hashtag-injected")
  end
end
