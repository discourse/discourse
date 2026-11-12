# frozen_string_literal: true

describe "Discourse Livestream - Livestream with Zoom webinar" do
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
    SiteSetting.livestream_zoom_enabled = true
    SiteSetting.livestream_zoom_sdk_key = "blah"
    SiteSetting.livestream_zoom_sdk_secret = "blah"

    stub_request(:get, "https://zoom.us/j/1234567890").to_return(status: 404)
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
        text: I18n.t("js.discourse_events.livestream.zoom.join"),
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
          text: I18n.t("js.discourse_events.livestream.zoom.join"),
        )
        expect(page).to have_content(I18n.t("js.discourse_events.livestream.zoom.too_early"))
      end
    end
  end

  context "when the user is anonymous" do
    let(:dialog) { PageObjects::Components::Dialog.new }

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

    it "opens the webinar and offers signup to join its chat when guest viewing is enabled" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      post =
        create_post_with_event(
          current_user,
          'status="public" livestream="true" allowAnonymousLivestream="true" location="https://zoom.us/j/1234567890"',
          5.minutes.from_now,
        )

      topic_page.visit_topic(post.topic)
      find(".discourse-calendar-livestream-zoom-entry__join").click

      expect(dialog).to have_content(
        I18n.t("js.discourse_events.livestream.zoom.guest_prompt.message"),
      )
      dialog.click_no

      expect(page).to have_current_path("#{post.topic.relative_url}/zoom")
      expect(page).to have_css(".discourse-calendar-livestream-zoom-page__frame")

      click_button(I18n.t("js.discourse_events.livestream.chat.sign_up_to_chat"))

      expect(page).to have_current_path("/signup")
    end

    it "shows existing and live chat messages without a composer when guest reading is enabled" do
      SiteSetting.chat_allowed_groups =
        "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
      post =
        create_post_with_event(
          current_user,
          'status="public" livestream="true" allowAnonymousLivestream="true" location="https://zoom.us/j/1234567890"',
          5.minutes.from_now,
        )
      channel = post.topic.topic_chat_channel.chat_channel
      channel.add(current_user)
      Fabricate(:chat_message, chat_channel: channel, message: "Welcome to the webinar")

      topic_page.visit_topic(post.topic)
      find(".event-status .going-button").click
      dialog.click_no

      within(".discourse-calendar-livestream-zoom-page__chat") do
        expect(page).to have_content("Welcome to the webinar")
        expect(page).to have_css(".chat-channel-preview-card.--anon")
        expect(page).to have_no_css(".chat-composer")

        Chat::CreateMessage.call!(
          params: {
            chat_channel_id: channel.id,
            message: "The webinar is starting",
          },
          guardian: current_user.guardian,
        )

        expect(page).to have_content("The webinar is starting")
      end
    end

    it "takes guests to sign in when they choose to register after clicking an attendance button" do
      post =
        create_post_with_event(
          current_user,
          'status="public" livestream="true" allowAnonymousLivestream="true" location="https://zoom.us/j/1234567890"',
          5.minutes.from_now,
        )

      topic_page.visit_topic(post.topic)
      find(".event-status .going-button").click
      dialog.click_yes

      expect(page).to have_current_path("/login")
    end
  end
end
