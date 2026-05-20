# frozen_string_literal: true

describe "Composer - Create event action" do
  fab!(:admin)
  fab!(:events_category) { Fabricate(:category, name: "Events") }
  fab!(:regular_category) { Fabricate(:category, name: "General") }

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_events_category_type_setup = true
    DiscourseCalendar::Categories::Types::Events.configure_category(
      events_category,
      guardian: admin.guardian,
    )
    sign_in(admin)
  end

  it "opens the composer in event mode for events-type categories" do
    visit("/new-topic?category_id=#{events_category.id}")

    expect(composer).to have_value(
      %r{\A\[event start="[^"]+" status="public" timezone="[^"]+"\]\n\[/event\]\z},
    )
    expect(composer.button_label.text).to eq(
      I18n.t("js.discourse_post_event.composer.create_event_button"),
    )
    expect(page).to have_css(
      "#reply-title[placeholder='#{I18n.t("js.discourse_post_event.composer.event_title_placeholder")}']",
    )
  end

  it "creates a topic with an event post when submitted" do
    visit("/new-topic?category_id=#{events_category.id}")
    composer.fill_title("Team offsite kickoff")
    composer.create

    expect(page).to have_current_path(%r{/t/team-offsite-kickoff/})
    topic = Topic.find_by(title: "Team offsite kickoff")
    expect(topic).to be_present
    expect(DiscoursePostEvent::Event.exists?(id: topic.first_post.id)).to be(true)
  end

  it "does not enter event mode for non-events categories" do
    visit("/new-topic?category_id=#{regular_category.id}")

    expect(composer).to have_no_value(/\A\[event /)
    expect(composer.button_label.text).to eq(I18n.t("js.composer.create_topic"))
  end
end
