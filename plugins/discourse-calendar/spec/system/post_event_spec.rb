# frozen_string_literal: true

describe "Post event" do
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
    let(:location) { "123 Main St, Brisbane, Australia http://example.com" }

    it "can save a location" do
      title = "My test meetup event"
      raw = "[event start='2222-02-22 14:22']\n[/event]"
      post = PostCreator.create(admin, title:, raw:)

      visit(post.topic.url)
      post_event_page.edit
      post_event_form_page.fill_location(location)
      post_event_form_page.submit

      expect(post_event_page).to have_location(location)
      expect(page).to have_css(".event-location a[href='http://example.com']")
    end
  end

  context "with description" do
    it "can save a description" do
      title = "My descriptive meetup event"
      raw = "[event start='2222-02-22 14:22']\n[/event]"
      post = PostCreator.create(admin, title:, raw:)

      visit(post.topic.url)
      post_event_page.edit
      post_event_form_page.fill_description(
        "this is a test description\n and a link http://example.com",
      )
      post_event_form_page.submit

      expect(post_event_page).to have_description(
        %r{this is a test description\s+and a link http://example.com},
      )
    end

    it "shows the full description without a toggle in the topic view" do
      title = "Event with full description"
      description = "A short event description"
      raw = "[event start='2222-02-22 14:22']\n#{description}\n[/event]"
      post = PostCreator.create(admin, title:, raw:)

      visit(post.topic.url)

      expect(post_event_page).to have_description(description)
      expect(post_event_page).to have_no_description_toggle
    end

    it "correctly builds a multiline description" do
      timezone = "Europe/Paris"
      admin.user_option.update!(timezone:)

      time = Time.new(2025, 6, 15, 14, 30, 0, "+02:00")
      freeze_time(time)
      page.driver.with_playwright_page { |pw_page| pw_page.clock.install(time:) }

      visit("/new-topic")
      find(".toolbar-menu__options-trigger").click
      click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))

      # Toolbar inserts inline; fill the description in the preview editor and
      # focus out to flush back to raw.
      composer.preview.find(".composer-event__description-textarea").fill_in(with: "foo\nbar")
      find(".d-editor-input").click

      expect(composer).to have_value <<~EVENT.strip
        [event start="2025-06-15 15:00" status=public timezone=#{timezone} end="2025-06-15 16:00" reminders=notification.15.minutes]
        foo
        bar
        [/event]
      EVENT
    end
  end

  context "with markdown-mode preview" do
    it "inserts BBCode inline and renders the compact editor in the preview pane pre-populated" do
      visit("/new-topic")
      find(".toolbar-menu__options-trigger").click
      click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))

      preview = composer.preview
      expect(preview).to have_css(".composer-event-node")
      expect(preview.find(".composer-event__date-input", match: :first).value).not_to(
        be_empty,
        "start date should be populated from the inserted BBCode",
      )
      expect(composer).to have_value(/\[event /)
    end

    it "preserves a multi-day end date when toggling all-day on" do
      visit("/new-topic")
      composer.fill_title("Multi-day all-day toggle")
      composer.fill_content <<~MD
        [event start='2024-06-01 10:00' end='2024-06-03 12:00' timezone='UTC' status='public']
        [/event]
      MD

      preview = composer.preview
      expect(preview).to have_css(".composer-event-node")

      preview.find(".composer-event__all-day-toggle .d-toggle-switch__label").click
      find(".d-editor-input").click

      expect(composer).to have_value(/start=2024-06-01/)
      expect(composer).to have_value(/end=2024-06-03/)
    end

    context "when showLocalTime is set and the event crosses midnight relative to the viewer",
            timezone: "Australia/Brisbane" do
      it "renders the preview badge in the event timezone, not the viewer's" do
        # 2025-09-07 22:30 Europe/Paris == 2025-09-08 06:30 Australia/Brisbane,
        # so without showLocalTime the viewer would see "Sep 8" in the badge.
        # With showLocalTime, the preview must stay anchored to the event timezone.
        visit("/new-topic")
        composer.fill_title("Local time preview test")
        composer.fill_content <<~MD
          [event start='2025-09-07 22:30' timezone='Europe/Paris' showLocalTime='true' status='public']
          [/event]
        MD

        preview = composer.preview
        expect(preview).to have_css(".composer-event__month", text: "SEP")
        expect(preview).to have_css(".composer-event__day", text: "7")
      end
    end
  end

  context "with max attendees" do
    it "updates the going button label from Full after toggling" do
      going = I18n.t("js.discourse_post_event.models.invitee.status.going")
      full = I18n.t("js.discourse_post_event.models.event.full")
      raw = "[event status='public' start='2222-02-22 14:22' max-attendees='1']\n[/event]"
      post = PostCreator.create(admin, title: "My test meetup event", raw:)

      visit(post.topic.url)

      # Wait for the component to settle before clicking
      expect(page).to have_css(".going-button", text: going)
      post_event_page.going
      expect(page).to have_css(".going-button", text: full)

      post_event_page.going
      expect(page).to have_css(".going-button", text: going)
      expect(page).to have_no_css(".going-button", text: full)
    end
  end

  context "when defaulting timezone" do
    it "uses the user's profile timezone in the builder" do
      admin.user_option.update!(timezone: "Europe/Paris")

      visit("/new-topic")

      find(".toolbar-menu__options-trigger").click
      click_button(I18n.t("js.discourse_post_event.builder_modal.attach"))

      # Toolbar inserts inline; click gear to open the modal on advanced.
      find(".d-editor-preview .composer-event__more-dropdown button").click

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

      title = "My FR test meetup event"
      raw = <<~MD
        [event showLocalTime='true' start='2025-09-07 17:30' timezone='Europe/Paris']
        [/event]
      MD
      post = PostCreator.create(admin, title:, raw:)

      visit(post.topic.url)

      expect(page).to have_css(".event-date .month", text: "SEP")
      expect(page).to have_css(".event-date .day", text: "7")
    end

    it "shows correct date" do
      title = "My JP test meetup event"
      raw = "[event timezone='Japan' showLocalTime='true' start='2222-02-22 14:22']\n[/event]"
      post = PostCreator.create(admin, title:, raw:)

      visit(post.topic.url)

      expect(page).to have_css(".discourse-local-date", text: "Japan")
    end
  end

  it "safely renders event name" do
    title = "My XSS test meetup event"
    raw = "[event name=':cat: <script>alert(1);</script>' start='2222-02-22 00:00']\n[/event]"
    post = PostCreator.create(admin, title:, raw:)

    visit(post.topic.url)

    expect(page).to have_css(".event-info .name img.emoji[title='cat']")
    expect(page).to have_css(".event-info .name", text: "<script>alert(1);</script>")
  end

  it "can create, close, and open an event" do
    visit "/new-topic"
    title = "My upcoming l33t event"
    tomorrow = 1.day.from_now.strftime("%Y-%m-%d")
    composer.fill_title(title)
    composer.fill_content <<~MD
      [event start="#{tomorrow} 13:37" status="public"]
      [/event]
    MD
    composer.submit

    expect(page).to have_content(title)

    post_event_page.close
    post_event_page.open

    try_until_success { post_event_page.going }.open_more_menu do
      locator(".show-all-participants").click
    end

    find(".d-modal input.filter").fill_in(with: user.username)
    find(".d-modal .add-invitee").click

    topic_page = PageObjects::Pages::Topic.new

    topic = Topic.find(topic_page.current_topic_id)
    event = topic.posts.first.event
    expect(event.invitees.count).to eq(2)
  end

  it "does not show participants button when event is standalone" do
    title = "My standalone event"
    raw = "[event name='standalone-event' status='standalone' start='2222-02-22 00:00']\n[/event]"
    post = PostCreator.create(admin, title:, raw:)

    visit(post.topic.url)
    post_event_page.open_more_menu

    expect(page).to have_no_css(".show-all-participants")
  end

  it "does not show 'send pm' button to the user who created the event" do
    title = "My test meetup event"
    raw = "[event name='cool-event' status='public' start='2222-02-22 00:00']\n[/event]"
    post = PostCreator.create(admin, title:, raw:)

    visit(post.topic.url)
    post_event_page.going.open_more_menu

    expect(page).to have_no_css(".send-pm-to-creator")
  end

  context "with the Going button" do
    fab!(:rsvp_user, :user)

    before { sign_in(rsvp_user) }

    it "creates a recurring going invitee when picking 'this event and all following events'" do
      raw = "[event status='public' start='2222-02-22 14:22' recurrence='every_week']\n[/event]"
      post = PostCreator.create!(admin, title: "My recurring meetup event", raw:)

      visit(post.topic.url)
      post_event_page.going_all_following

      expect(post_event_page).to have_going_status
      invitee = DiscoursePostEvent::Invitee.find_by(user_id: rsvp_user.id, post_id: post.id)
      expect(invitee.status).to eq(DiscoursePostEvent::Invitee.statuses[:going])
      expect(invitee.recurring).to eq(true)
    end

    it "creates a non-recurring going invitee when picking 'this event'" do
      raw = "[event status='public' start='2222-02-22 14:22' recurrence='every_week']\n[/event]"
      post = PostCreator.create!(admin, title: "My recurring meetup event", raw:)

      visit(post.topic.url)
      post_event_page.going_this_event

      expect(post_event_page).to have_going_status
      invitee = DiscoursePostEvent::Invitee.find_by(user_id: rsvp_user.id, post_id: post.id)
      expect(invitee.status).to eq(DiscoursePostEvent::Invitee.statuses[:going])
      expect(invitee.recurring).to eq(false)
    end

    it "renders without a dropdown on non-recurring events" do
      raw = "[event status='public' start='2222-02-22 14:22']\n[/event]"
      post = PostCreator.create!(admin, title: "My one-off meetup event", raw:)

      visit(post.topic.url)

      expect(post_event_page).to have_going_button
      expect(post_event_page).to have_no_going_menu
    end

    it "opens the menu when tapping the whole going button on mobile", mobile: true do
      raw = "[event status='public' start='2222-02-22 14:22' recurrence='every_week']\n[/event]"
      post = PostCreator.create!(admin, title: "My recurring meetup event", raw:)

      visit(post.topic.url)
      post_event_page.going

      expect(page).to have_css(".discourse-post-event-going-menu-content")
    end
  end

  it "shows '-' for expired recurring events instead of dates" do
    title = "An expired recurring event"
    raw = <<~MD
      [event start='2024-01-01 10:00' recurrenceUntil='2025-07-31' recurrence='every_week']
      [/event]
    MD
    post = PostCreator.create!(admin, title:, raw:)

    visit(post.topic.url)

    expect(page).to have_css(".discourse-post-event")
    expect(page).to have_css(".event-date .month", text: "-")
    expect(page).to have_css(".event-date .day", text: "-")
    expect(page).to have_css(".event-dates", text: "-")
  end

  context "with DST handling for recurring events" do
    fab!(:eu_viewer) do
      user = Fabricate(:user)
      user.user_option.update!(timezone: "Europe/Paris")
      user
    end

    fab!(:us_viewer) do
      user = Fabricate(:user)
      user.user_option.update!(timezone: "America/New_York")
      user
    end

    def verify_event_time(viewer:, time:, expected_month: nil, expected_day: nil, expected_time:)
      freeze_time(time) do
        title = "Weekly recurring event #{SecureRandom.hex(4)}"
        raw = <<~MD
          [event start='2025-10-15 11:00' timezone='America/New_York' recurrence='every_week']
          [/event]
        MD
        post = PostCreator.create!(admin, title:, raw:)

        event = DiscoursePostEvent::Event.find_by(post:)
        event.set_next_date

        sign_in(viewer)

        # Freeze browser clock **after** sign_in (which may navigate/reset state)
        # so moment() uses the same time as the server.
        page.driver.with_playwright_page { |pw_page| pw_page.clock.install(time:) }

        visit(post.topic.url)

        expect(page).to have_css(".event-date .month", text: expected_month) if expected_month
        expect(page).to have_css(".event-date .day", text: expected_day) if expected_day
        expect(page).to have_css(".discourse-local-date", text: expected_time)
      end
    end

    context "when viewer is in Europe/Paris timezone", timezone: "Europe/Paris" do
      it "shows correct time before any DST transition" do
        # Oct 14, 2025 - Both Europe and US are in summer time
        # 11:00 AM EDT = 15:00 UTC = 17:00 CEST = 5:00 PM
        verify_event_time(
          viewer: eu_viewer,
          time: Time.new(2025, 10, 14, 10, 0, 0, "+02:00"),
          expected_month: "OCT",
          expected_day: "15",
          expected_time: "5:00 PM",
        )
      end

      it "shows correct time after Europe DST ends but before US DST ends" do
        # Oct 28, 2025 - Europe CET (UTC+1), US still EDT (UTC-4)
        # 11:00 AM EDT = 15:00 UTC = 16:00 CET = 4:00 PM
        verify_event_time(
          viewer: eu_viewer,
          time: Time.new(2025, 10, 28, 10, 0, 0, "+01:00"),
          expected_month: "OCT",
          expected_day: "29",
          expected_time: "4:00 PM",
        )
      end

      it "shows correct time after both DST transitions" do
        # Nov 4, 2025 - Europe CET (UTC+1), US EST (UTC-5)
        # 11:00 AM EST = 16:00 UTC = 17:00 CET = 5:00 PM
        verify_event_time(
          viewer: eu_viewer,
          time: Time.new(2025, 11, 4, 10, 0, 0, "+01:00"),
          expected_month: "NOV",
          expected_day: "5",
          expected_time: "5:00 PM",
        )
      end
    end

    context "when viewer is in America/New_York timezone", timezone: "America/New_York" do
      it "shows 11:00 AM before US DST ends" do
        verify_event_time(
          viewer: us_viewer,
          time: Time.new(2025, 10, 28, 10, 0, 0, "-04:00"),
          expected_time: "11:00 AM",
        )
      end

      it "shows 11:00 AM after US DST ends" do
        verify_event_time(
          viewer: us_viewer,
          time: Time.new(2025, 11, 4, 10, 0, 0, "-05:00"),
          expected_time: "11:00 AM",
        )
      end
    end
  end

  it "persists changes" do
    visit "/new-topic"
    composer.fill_title("Test event with updates")
    find(".toolbar-menu__options-trigger").click
    find("button[title='#{I18n.t("js.discourse_post_event.builder_modal.attach")}']").click

    # Toolbar inserts inline; click gear to open the modal on advanced.
    find(".d-editor-preview .composer-event__more-dropdown button").click

    form = PageObjects::Components::FormKit.new(".d-modal form")
    form.field("eventType").select("private")
    find(".group-selector").click
    find(".d-multi-select__search-input").send_keys(group.name)
    find(".d-multi-select__result", text: group.name).click
    form.field("customFields.custom").fill_in("custom value")
    form.field("recurrence").select("every_day")
    find(".d-modal .recurrence-until .date-picker").fill_in(with: "#{1.year.from_now.year}-12-30")
    find(".d-modal .btn-primary").click
    composer.submit

    expect(page).to have_css(".discourse-post-event")

    post_event_page.edit
    find(".d-modal .d-modal__footer .advanced-mode-btn").click

    form = PageObjects::Components::FormKit.new(".d-modal form")
    expect(form.field("eventType")).to have_value("private")
    expect(find(".group-selector .d-multi-select-trigger__selection")).to have_text(group.name)
    expect(form.field("customFields.custom")).to have_value("custom value")
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

    it "keeps a single row when removing the last invitee" do
      visit(post.topic.url)

      post_event_page.open_bulk_invite_modal
      bulk_invite_modal_page
        .set_invitee_at_row(invitable_user_1.username, "going", 1)
        .add_invitee
        .set_invitee_at_row(invitable_user_2.username, "not_going", 2)
        .remove_invitee_row(2)
        .remove_invitee_row(1)

      # the collection never collapses, an empty row is always available
      expect(bulk_invite_modal_page).to have_invitee_rows(1)
    end

    it "closes the modal and shows a toast after a CSV bulk invite" do
      visit(post.topic.url)

      post_event_page.open_bulk_invite_modal
      bulk_invite_modal_page.upload_csv(
        "#{Rails.root.join("plugins/discourse-calendar/spec/fixtures/csv/bulk_invite.csv")}",
      )
      PageObjects::Components::Dialog.new.click_yes

      expect(bulk_invite_modal_page).to be_closed
      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("js.discourse_post_event.bulk_invite_modal.success"),
      )
    end
  end

  context "when inviting a user or group" do
    let!(:post) do
      PostCreator.create(
        admin,
        title: "My test meetup event",
        raw: "[event name='cool-event' status='public' start='2222-02-22 00:00' ]\n[/event]",
      )
    end

    fab!(:invitable_user, :user)

    it "notifies the invited user and closes the modal" do
      visit(post.topic.url)

      post_event_page.open_invite_user_or_group_modal

      chooser =
        PageObjects::Components::SelectKit.new(
          ".post-event-invite-user-or-group .email-group-user-chooser",
        )
      chooser.expand
      chooser.search(invitable_user.username)
      chooser.select_row_by_value(invitable_user.username)
      chooser.collapse

      find(".post-event-invite-user-or-group .d-modal__footer .btn-primary").click

      expect(page).to have_no_css(".post-event-invite-user-or-group")
      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("js.discourse_post_event.invite_user_or_group.success"),
      )
      expect(
        invitable_user.notifications.where(
          notification_type: Notification.types[:event_invitation],
        ),
      ).to be_present
    end
  end

  context "with add to calendar from more menu" do
    it "includes rrule for recurring events" do
      admin.user_option.update!(default_calendar: "ics")

      title = "Weekly standup"
      raw = <<~MD
        [event start='2222-02-22 14:00' recurrence='every_week']
        [/event]
      MD
      post = PostCreator.create!(admin, title:, raw:)

      visit(post.topic.url)

      ics_content = nil
      page.driver.with_playwright_page do |pw_page|
        download = pw_page.expect_download { post_event_page.add_to_calendar }
        ics_content = download.path.then { |path| File.read(path) }
      end

      expect(ics_content).to include("RRULE:")
      expect(ics_content).to include("FREQ=WEEKLY")
    end
  end

  context "when editing an event without an explicit name" do
    it "shows the topic title as the event name placeholder" do
      title = "Nameless meetup"
      raw = "[event start='2222-02-22 14:22']\n[/event]"
      post = PostCreator.create!(admin, title:, raw:)

      visit(post.topic.url)
      post_event_page.edit

      expect(page).to have_css(
        ".post-event-builder-modal .composer-event__name-input[placeholder='#{title}']",
      )
    end
  end
end
