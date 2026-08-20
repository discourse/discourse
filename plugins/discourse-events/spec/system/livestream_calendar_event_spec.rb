# frozen_string_literal: true

describe "Discourse Livestream - Topic Livestream with events - Authenticated" do
  fab!(:group)
  fab!(:current_user) { Fabricate(:user, trust_level: 1, groups: [group]) }
  fab!(:category)
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_livestream) { PageObjects::Pages::TopicLivestream.new }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s
    topic_livestream.cache_livestream_onebox
    sign_in(current_user)
  end

  context "when in a event topic view" do
    it "clicks going to join the chat channel for livestream topics" do
      topic_livestream.create_livestream_event_topic(composer, topic_page)

      find(".going-button", wait: 25).click
      expect(topic_page).to have_css(".confirmed-event-assistance", wait: 25)

      find(".not-going-button").click
      expect(topic_page).not_to have_css(".confirmed-event-assistance", wait: 25)
    end

    it "keeps the going styles when entering the topic below the first post" do
      topic = Fabricate(:topic, category:)
      first_post = Fabricate(:post, topic:)
      event =
        DiscoursePostEvent::Event.create!(
          id: first_post.id,
          original_starts_at: 1.day.from_now,
          original_ends_at: 2.days.from_now,
          livestream: true,
          location: PageObjects::Pages::TopicLivestream::LIVESTREAM_URL,
        )
      DiscoursePostEvent::Invitee.create_attendance!(current_user.id, event.id, :going)
      25.times { Fabricate(:post, topic:) }

      visit "/t/#{topic.slug}/#{topic.id}/26"

      expect(topic_page).to have_css("#post_26")
      expect(topic_page).to have_no_css("#post_1")
      expect(topic_page).to have_css("body.confirmed-event-assistance", wait: 25)
    end

    it "clicks going to join the chat channel for livestream topics" do
      topic_livestream.create_normal_event_topic(composer, topic_page)

      find(".going-button", wait: 25).click
      expect(topic_page).to have_css(".confirmed-event-assistance", wait: 25)

      find(".not-going-button").click
      expect(topic_page).not_to have_css(".confirmed-event-assistance", wait: 25)
    end
  end
end
