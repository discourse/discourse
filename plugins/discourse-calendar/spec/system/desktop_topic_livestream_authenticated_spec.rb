# frozen_string_literal: true

describe "Discourse Livestream - Topic Livestream - Desktop - Authenticated" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_livestream) { PageObjects::Pages::TopicLivestream.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:everyone].to_s
    topic_livestream.cache_livestream_onebox
    sign_in(current_user)
  end

  context "when in a topic view" do
    it "creates a chat channel for livestream topics" do
      topic_livestream.create_livestream_event_topic(composer, topic_page)

      expect(topic_page).to have_css("#custom-chat-container")
      expect(topic_page).to have_css("#custom-chat-container .chat-channel-preview-card")
      expect(topic_page).to have_text(I18n.t("js.discourse_calendar.livestream.chat.rsvp_to_event"))
    end

    it "does not create a chat channel for regular topics" do
      topic_livestream.create_regular_topic(composer, topic_page)

      expect(topic_page).not_to have_css("#custom-chat-container")
      expect(topic_page).not_to have_text(
        I18n.t("js.discourse_calendar.livestream.chat.rsvp_to_event"),
      )
    end
  end
end
