# frozen_string_literal: true

describe "Event card" do
  fab!(:admin)
  fab!(:category)
  fab!(:upload) { Fabricate(:image_upload, width: 1000, height: 800) }

  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.events_calendar_categories = category.id.to_s
    sign_in(admin)
  end

  it "links the hero image to the topic", time: Time.zone.parse("2026-07-13 12:00:00") do
    post =
      PostCreator.create!(
        admin,
        title: "Boat party with a banner",
        category: category.id,
        raw:
          "[event start=\"#{2.hours.from_now.iso8601}\" end=\"#{3.hours.from_now.iso8601}\"]\n[/event]",
      )
    DiscoursePostEvent::Event.find(post.id).update!(image_upload: upload)

    category_page.visit(category)

    expect(page).to have_css("#category-events-calendar .fc")
    find(
      ".fc-daygrid-event-harness .fc-event-title",
      text: "Boat party with a banner",
      match: :first,
    ).click

    expect(page).to have_css(".discourse-post-event .event-image img")
    # the hero image links to the topic, not to the upload file (lightbox)
    expect(page).to have_css(".discourse-post-event .event-image a[href*='/t/']")
    expect(page).to have_no_css(".discourse-post-event .event-image a.lightbox")
  end
end
