# frozen_string_literal: true

RSpec.describe "Event topic links in chat" do
  fab!(:current_user, :user)
  fab!(:channel, :category_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:event_onebox) { PageObjects::Components::DiscourseEvents::ChatEventOnebox.new }
  let(:event_post) { PostCreator.create!(current_user, title: "Community meetup", raw: <<~RAW) }
        [event start="2026-11-12 11:00" end="2026-11-12 12:00" status="public" timezone="Australia/Brisbane"]
        Join us for the community meetup.
        [/event]
      RAW
  let(:event) { DiscourseEvents::Events::Event.find(event_post.id) }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:everyone].to_s
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  it "shows the event widget after the user links an event topic",
     time: Time.zone.parse("2026-10-23 12:00:00") do
    chat_page.visit_channel(channel)
    channel_page.send_message(event_post.topic.url)

    expect(event_onebox).to have_event(event)
  end
end
