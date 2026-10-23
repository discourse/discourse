# frozen_string_literal: true

describe "Post calendar" do
  fab!(:admin)
  fab!(:calendar_user) { Fabricate(:user, trust_level: 1) }
  fab!(:viewer, :user)

  let(:calendar_post) { create_post(user: admin, raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic.id
    sign_in(viewer)
  end

  it "sanitizes markup from calendar replies in tooltips", time: Time.utc(2026, 8, 1, 12, 0) do
    create_post(
      user: calendar_user,
      topic: calendar_post.topic,
      raw:
        "`<a id=\"calendar-tooltip-link\" href=\"https://example.com\" style=\"position: fixed; inset: 0; z-index: 9999\">Cover page</a>` [date=\"2026-08-02\"]",
    )

    visit(calendar_post.topic.url)

    expect(page.status_code).to eq(200)
    find(".fc-event", text: calendar_user.username).hover
    expect(page).to have_css("[data-identifier='post-event-tooltip']")
    expect(page).to have_no_css("#calendar-tooltip-link")
  end

  it "shows the calendar on the post" do
    away_post =
      create_post(
        user: admin,
        topic: calendar_post.topic,
        raw: "Away [date=#{Time.now.strftime("%Y-%m-%d")}]",
      )

    visit(calendar_post.topic.url)

    expect(page).to have_css(
      ".fc-daygrid-event-harness .fc-event-title",
      text: away_post.user.username,
    )
  end
end
