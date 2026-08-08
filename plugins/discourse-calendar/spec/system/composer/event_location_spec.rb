# frozen_string_literal: true

describe "Composer - Event location" do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:markdown_location) { "[RSVP](https://zoom.example.com/j/123)" }
  let(:event_markup) { <<~MD.strip }
    [event start="2026-08-01 18:00" status="public" timezone="UTC" location="#{markdown_location}"]
    [/event]
  MD

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  it "renders a markdown-link location on the posted card and keeps it stable when edited in the markdown composer" do
    visit("/new-topic")
    composer.fill_title("Event with a markdown location")
    composer.fill_content(event_markup)

    expect(page.find(".composer-event__location-input").value).to eq(markdown_location)

    composer.create

    expect(page).to have_css(
      ".event-location a[href='https://zoom.example.com/j/123']",
      text: "RSVP",
    )

    topic = Topic.find_by(title: "Event with a markdown location")
    find("#post_1 .show-more-actions").click
    find("#post_1 .edit").click

    expect(page.find(".composer-event__location-input").value).to eq(markdown_location)

    composer.create

    expect(page).to have_css(".event-location a", text: "RSVP")
    expect(DiscoursePostEvent::Event.find(topic.first_post.id).location).to eq(markdown_location)
  end

  it "shows the link affordance for scheme-less urls, matching what the card links" do
    visit("/new-topic")
    composer.fill_title("Event with a scheme-less location")
    composer.fill_content(<<~MD.strip)
      [event start="2026-08-01 18:00" status="public" timezone="UTC" location="zoom.us/j/123"]
      [/event]
    MD

    expect(page).to have_css(".composer-event__location-external-link[href='http://zoom.us/j/123']")

    composer.create

    expect(page).to have_css(".event-location a", text: "zoom.us/j/123")
  end

  context "with the rich editor" do
    include_context "with prosemirror editor"

    it "round-trips a markdown-link location through the event node" do
      open_composer
      composer.toggle_rich_editor
      composer.fill_content(event_markup)
      composer.toggle_rich_editor

      expect(rich.find(".composer-event__location-input").value).to eq(markdown_location)

      composer.toggle_rich_editor

      expect(composer).to have_value(%r{location="\[RSVP\]\(https://zoom\.example\.com/j/123\)"})
    end
  end
end
