# frozen_string_literal: true

describe "Discourse Livestream - Topic Livestream with events - Authenticated" do
  fab!(:group)
  fab!(:current_user) { Fabricate(:user, trust_level: 1, groups: [group]) }
  fab!(:category)
  fab!(:livestream_tag) { Fabricate(:tag, name: "livestream") }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_livestream) { PageObjects::Pages::TopicLivestream.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s
    topic_livestream.cache_livestream_onebox
    sign_in(current_user)
  end

  context "when in a event topic view" do
    it "clicks going to join the chat channel for livestream topics" do
      topic_livestream.create_livestream_event_topic(composer, topic_page, livestream_tag)

      find(".going-button", wait: 25).click
      expect(topic_page).to have_css(".confirmed-event-assistance", wait: 25)

      find(".not-going-button").click
      expect(topic_page).not_to have_css(".confirmed-event-assistance", wait: 25)
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
