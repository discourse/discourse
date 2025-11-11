# frozen_string_literal: true

describe "Post calendar", type: :system do
  fab!(:admin)

  let(:calendar_post) { create_post(user: admin, raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic.id
    sign_in(admin)
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
