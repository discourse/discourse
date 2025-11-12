# frozen_string_literal: true

describe "Post event", type: :system do
  fab!(:admin)
  fab!(:user, :admin)
  fab!(:group)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:post_event_page) { PageObjects::Pages::DiscourseCalendar::PostEvent.new }
  let(:post_event_form_page) { PageObjects::Pages::DiscourseCalendar::PostEventForm.new }
  let(:bulk_invite_modal_page) { PageObjects::Pages::DiscourseCalendar::BulkInviteModal.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_custom_fields = "custom"
    sign_in(admin)
  end

  context "with location" do
    it "can save a location" do
      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw: "[event start='2222-02-22 14:22']\n[/event]",
        )

      visit(post.topic.url)
      post_event_page.edit
      post_event_form_page.fill_location("123 Main St, Brisbane, Australia http://example.com")
      post_event_form_page.submit

      expect(post_event_page).to have_location(
        "123 Main St, Brisbane, Australia http://example.com",
      )
      expect(page).to have_css(".event-location a[href='http://example.com']")
    end
  end

  context "with description" do
    it "can save a description" do
      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw: "[event start='2222-02-22 14:22']\n[/event]",
        )

      visit(post.topic.url)
      post_event_page.edit
      post_event_form_page.fill_description(
        "this is a test description\n and a link http://example.com",
      )
      post_event_form_page.submit

      expect(post_event_page).to have_description(
        %r{this is a test description\s+and a link http://example.com},
      )
      expect(page).to have_css(".event-description a[href='http://example.com']")
    end

    it "correctly builds a multiline description", timezone: "Europe/Paris" do
      visit("/new-topic")

      time = Time.now.strftime("%Y-%m-%d %H:%M")

      EXPECTED_BBCODE = <<~EVENT
        [event start="#{time}" status="public" timezone="Europe/Paris"]
        foo
        bar
        [/event]
      EVENT

      find(".toolbar-menu__options-trigger").click
      click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))
      post_event_form_page.fill_description("foo\nbar").fill_timezone("Europe/Paris").submit

      expect(composer).to have_value(EXPECTED_BBCODE.strip)
    end
  end

  context "with max attendees" do
    it "updates the going button label from Full after toggling" do
      post =
        PostCreator.create(
          admin,
          title: "Max attendees event",
          raw: "[event status='public' start='2222-02-22 14:22' max-attendees='1']\n[/event]",
        )

      visit(post.topic.url)

      # First click: join the event; since max is 1, it reaches capacity and shows Full
      post_event_page.going
      expect(page).to have_css(
        ".going-button",
        text: I18n.t("js.discourse_post_event.models.event.full"),
      )

      # Second click: leave the event; label should no longer be Full
      post_event_page.going
      expect(page).to have_no_css(
        ".going-button",
        text: I18n.t("js.discourse_post_event.models.event.full"),
      )
      expect(page).to have_css(
        ".going-button",
        text: I18n.t("js.discourse_post_event.models.invitee.status.going"),
      )
    end
  end

  context "when defaulting timezone" do
    it "uses the user's profile timezone in the builder" do
      admin.user_option.update!(timezone: "Europe/Paris")

      visit("/new-topic")

      find(".toolbar-menu__options-trigger").click
      click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))

      tz_select =
        PageObjects::Components::SelectKit.new(".post-event-builder-modal .timezone-input")

      # Expect the timezone select to default to the user's timezone
      expect(tz_select.value).to eq("Europe/Paris")
    end
  end

  context "when showing local time", timezone: "Australia/Brisbane" do
    it "correctly shows month/day" do
      page.driver.with_playwright_page do |pw_page|
        pw_page.clock.install(time: Time.new(2025, 6, 5, 22, 0, 0))
      end

      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw:
            "[event showLocalTime='true' start='2025-09-07 17:30' start='2025-09-07 18:30' timezone='Europe/Paris']\n[/event]",
        )

      visit(post.topic.url)

      expect(page).to have_css(".event-date .month", text: "SEP")
      expect(page).to have_css(".event-date .day", text: "7")
    end

    it "shows correct date" do
      post =
        PostCreator.create(
          admin,
          title: "My test meetup event",
          raw: "[event timezone='Japan' showLocalTime='true' start='2222-02-22 14:22']\n[/event]",
        )

      visit(post.topic.url)

      expect(page).to have_css(".discourse-local-date", text: "Japan")
    end
  end

  it "safely renders event name" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name=':cat: <script>alert(1);</script>' start='2222-02-22 00:00']\n[/event]",
      )

    visit(post.topic.url)

    expect(page).to have_css(".event-info .name img.emoji[title='cat']")
    expect(page).to have_css(".event-info .name", text: "<script>alert(1);</script>")
  end

  it "can create, close, and open an event" do
    visit "/new-topic"
    title = "My upcoming l33t event"
    tomorrow = (1.day.from_now).strftime("%Y-%m-%d")
    composer.fill_title(title)
    composer.fill_content <<~MD
      [event start="#{tomorrow} 13:37" status="public"]
      [/event]
    MD
    composer.submit

    expect(page).to have_content(title)

    post_event_page.close
    post_event_page.open
    post_event_page.going.open_more_menu
    find(".show-all-participants").click
    find(".d-modal input.filter").fill_in(with: user.username)
    find(".d-modal .add-invitee").click

    topic_page = PageObjects::Pages::Topic.new

    topic = Topic.find(topic_page.current_topic_id)
    event = topic.posts.first.event
    expect(event.invitees.count).to eq(2)
  end

  it "does not show participants button when event is standalone" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='standalone' start='2222-02-22 00:00' ]\n[/event]",
      )
    visit(post.topic.url)
    post_event_page.open_more_menu

    expect(page).to have_no_css(".show-all-participants")
  end

  it "does not show 'send pm' button to the user who created the event" do
    post =
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='public' start='2222-02-22 00:00' ]\n[/event]",
      )

    visit(post.topic.url)
    post_event_page.going.open_more_menu

    expect(page).to have_no_css(".send-pm-to-creator")
  end

  it "shows '-' for expired recurring events instead of dates" do
    post =
      PostCreator.create!(
        admin,
        title: "An expired recurring event",
        raw:
          "[event start='2024-01-01 10:00' recurrenceUntil='2025-07-31' recurrence='every_week']\n[/event]",
      )

    visit(post.topic.url)

    expect(page).to have_css(".discourse-post-event")
    expect(page).to have_css(".event-date .month", text: "-")
    expect(page).to have_css(".event-date .day", text: "-")
    expect(page).to have_css(".event-dates", text: "-")
  end

  context "with DST handling for recurring events" do
    fab!(:viewer) do
      user = Fabricate(:user)
      user.user_option.update!(timezone: "Europe/Paris")
      user
    end

    it "maintains wall clock time (11:00 AM) in event timezone across all DST transitions" do
      # Before any DST
      freeze_time(Time.new(2025, 10, 14, 10, 0, 0, "+02:00")) do
        post =
          PostCreator.create!(
            admin,
            title: "Weekly recurring event across DST",
            raw:
              "[event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']\n[/event]",
          )

        event = DiscoursePostEvent::Event.find_by(post: post)
        event.set_next_date
        sign_in(viewer)
        visit(post.topic.url)

        expect(page).to have_css(".event-date .month", text: "OCT")
        expect(page).to have_css(".event-date .day", text: "15")
        expect(page).to have_css(".discourse-local-date", text: "5:00 PM")
      end

      # Test 2: After Europe DST
      freeze_time(Time.new(2025, 10, 28, 10, 0, 0, "+01:00")) do
        post =
          PostCreator.create!(
            admin,
            title: "Weekly recurring event 2",
            raw:
              "[event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']\n[/event]",
          )

        event = DiscoursePostEvent::Event.find_by(post: post)
        event.set_next_date
        sign_in(viewer)
        visit(post.topic.url)

        expect(page).to have_css(".event-date .month", text: "OCT")
        expect(page).to have_css(".event-date .day", text: "29")
        # This is the period where the time CHANGES for European viewers
        expect(page).to have_css(".discourse-local-date", text: "4:00 PM")
      end

      # Test 3: After both DST transitions
      freeze_time(Time.new(2025, 11, 4, 10, 0, 0, "+01:00")) do
        post =
          PostCreator.create!(
            admin,
            title: "Weekly recurring event 3",
            raw:
              "[event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']\n[/event]",
          )

        event = DiscoursePostEvent::Event.find_by(post: post)
        event.set_next_date
        sign_in(viewer)
        visit(post.topic.url)

        expect(page).to have_css(".event-date .month", text: "NOV")
        expect(page).to have_css(".event-date .day", text: "5")
        expect(page).to have_css(".discourse-local-date", text: "5:00 PM")
      end
    end

    it "event stays at wall clock time (11:00 AM) in its own timezone throughout DST" do
      us_viewer = Fabricate(:user)
      us_viewer.user_option.update!(timezone: "America/New_York")

      # Before US DST ends
      freeze_time(Time.new(2025, 10, 28, 10, 0, 0, "-04:00")) do
        post =
          PostCreator.create!(
            admin,
            title: "Weekly recurring event 4",
            raw:
              "[event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']\n[/event]",
          )

        event = DiscoursePostEvent::Event.find_by(post: post)
        event.set_next_date
        sign_in(us_viewer)
        visit(post.topic.url)

        expect(page).to have_css(".discourse-local-date", text: "11:00 AM")
      end

      # After US DST ends
      freeze_time(Time.new(2025, 11, 4, 10, 0, 0, "-05:00")) do
        post =
          PostCreator.create!(
            admin,
            title: "Weekly recurring event 5",
            raw:
              "[event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']\n[/event]",
          )

        event = DiscoursePostEvent::Event.find_by(post: post)
        event.set_next_date
        sign_in(us_viewer)
        visit(post.topic.url)

        expect(page).to have_css(".discourse-local-date", text: "11:00 AM")
      end
    end
  end

  it "persists changes" do
    visit "/new-topic"
    composer.fill_title("Test event with updates")
    find(".toolbar-menu__options-trigger").click
    find("button[title='#{I18n.t("js.discourse_post_event.builder_modal.attach")}']").click
    find(".d-modal input[name=status][value=private]").click
    find(".group-selector").click
    find(".d-multi-select__search-input").send_keys(group.name)
    find(".d-multi-select__result", text: group.name).click
    find(".d-modal .custom-field-input").fill_in(with: "custom value")
    dropdown = PageObjects::Components::SelectKit.new(".available-recurrences")
    dropdown.expand
    dropdown.select_row_by_value("every_day")
    find(".d-modal .recurrence-until .date-picker").fill_in(with: "#{1.year.from_now.year}-12-30")
    find(".d-modal .btn-primary").click
    composer.submit

    expect(page).to have_css(".discourse-post-event")

    post_event_page.edit

    expect(find(".d-modal input[name=status][value=private]").checked?).to eq(true)
    expect(find(".group-selector .d-multi-select-trigger__selection")).to have_text(group.name)
    expect(find(".d-modal .custom-field-input").value).to eq("custom value")
    expect(page).to have_selector(".d-modal .recurrence-until .date-picker") do |input|
      input.value == "#{1.year.from_now.year}-12-30"
    end
  end

  context "when using bulk inline invite" do
    let!(:post) do
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='public' start='2222-02-22 00:00' ]\n[/event]",
      )
    end

    fab!(:invitable_user_1, :user)
    fab!(:invitable_user_2, :user)

    it "can invite users to an event" do
      visit(post.topic.url)

      post_event_page.open_bulk_invite_modal
      bulk_invite_modal_page
        .set_invitee_at_row(invitable_user_1.username, "going", 1)
        .add_invitee
        .set_invitee_at_row(invitable_user_2.username, "not_going", 2)
        .send_invites

      expect(bulk_invite_modal_page).to be_closed
    end
  end
end
