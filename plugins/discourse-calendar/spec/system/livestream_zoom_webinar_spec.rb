# frozen_string_literal: true

describe "Discourse Livestream - Livestream with Zoom webinar" do
  fab!(:group)
  fab!(:current_user) { Fabricate(:user, trust_level: 1, groups: [group]) }
  fab!(:category)
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_livestream) { PageObjects::Pages::TopicLivestream.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s
    SiteSetting.livestream_zoom_enabled = true
    SiteSetting.livestream_zoom_sdk_key = "blah"
    SiteSetting.livestream_zoom_sdk_secret = "blah"
  end

  context "when user is signed in" do
    before { sign_in(current_user) }
    it "shows a Join Zoom button for livestream events which have a Zoom location" do
      topic_livestream.create_livestream_event_topic(
        composer,
        topic_page,
        location: "https://zoom.us/j/1234567890",
        start: 5.minutes.from_now.strftime("%Y-%m-%d %H:%M"),
      )

      expect(page).to have_css(
        ".discourse-calendar-livestream-zoom-entry__actions .btn",
        text: I18n.t("js.discourse_calendar.livestream.zoom.join"),
      )
    end

    context "when we are not close to the event start time" do
      it "shows a disabled Join Zoom button for livestream events which have a Zoom location" do
        topic_livestream.create_livestream_event_topic(
          composer,
          topic_page,
          location: "https://zoom.us/j/1234567890",
          start: 5.days.from_now.strftime("%Y-%m-%d %H:%M"),
        )

        expect(page).to have_css(
          ".discourse-calendar-livestream-zoom-entry__actions .btn[disabled]",
          text: I18n.t("js.discourse_calendar.livestream.zoom.join"),
        )
        expect(page).to have_content(I18n.t("js.discourse_calendar.livestream.zoom.too_early"))
      end
    end
  end

  context "when the user is anonymous" do
    it "redirects to the login page when clicking the Join Zoom button" do
      post =
        create_post_with_event(
          current_user,
          'status="public" livestream="true" location="https://zoom.us/j/1234567890"',
          5.minutes.from_now,
        )

      topic_page.visit_topic(post.topic)

      find(".discourse-calendar-livestream-zoom-entry__actions .btn").click

      expect(page).to have_css(".signup-fullpage")
      expect(page).to have_current_path("/signup")
    end
  end
end
