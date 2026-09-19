# frozen_string_literal: true

describe DiscourseEvents::Events::Onebox do
  fab!(:event) do
    Fabricate(
      :event,
      name: "Board game night",
      location: "Room A",
      timezone: "America/Sao_Paulo",
      original_starts_at: Time.utc(2026, 9, 20, 21),
      original_ends_at: Time.utc(2026, 9, 20, 23),
    )
  end

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  def preview(post = event.post, **opts)
    Nokogiri::HTML5.fragment(Oneboxer.preview(post.url, opts))
  end

  it "renders event details through the standard topic onebox" do
    html = preview

    expect(html.at_css("aside.quote")["data-topic"]).to eq(event.post.topic_id.to_s)
    expect(html.at_css("aside.quote")["data-post"]).to eq("1")
    expect(html.at_css(".title a")["href"]).to eq(event.post.url)
    expect(html.at_css(".discourse-event-onebox").text).to include(
      event.name,
      event.location,
      "September 20, 2026 6:00 PM",
      "September 20, 2026 8:00 PM",
      event.timezone,
    )
    expect(html.css(".discourse-post-event")).to be_empty
  end

  it "leaves ordinary topics and replies as standard quotes" do
    ordinary = Fabricate(:post)
    reply = Fabricate(:post, topic: event.post.topic)

    [ordinary, reply].each do |post|
      html = preview(post)
      expect(html.at_css("aside.quote")["data-post"]).to eq(post.post_number.to_s)
      expect(html.css(".discourse-event-onebox")).to be_empty
    end
  end

  it "uses the standard quote when post events are disabled" do
    SiteSetting.discourse_post_event_enabled = false

    html = preview

    expect(html.at_css("aside.quote")).to be_present
    expect(html.css(".discourse-event-onebox")).to be_empty
  end

  it "uses the standard quote when the events plugin is disabled" do
    SiteSetting.discourse_events_enabled = false

    expect(preview.css(".discourse-event-onebox")).to be_empty
  end

  it "uses the standard quote after an event is deleted" do
    event.update!(deleted_at: Time.now)

    expect(preview.css(".discourse-event-onebox")).to be_empty
  end

  it "omits hidden and deleted event posts" do
    event.post.update!(hidden: true)
    expect(preview.css("aside")).to be_empty

    event.post.update!(hidden: false, deleted_at: Time.now)
    expect(preview.css("aside")).to be_empty
  end

  it "keeps private event details out of public previews" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    event.post.topic.update!(category: private_category)

    html = preview

    expect(html.css("aside")).to be_empty
    expect(html.text).not_to include(event.name, event.location)
  end

  it "renders restricted events only in a permitted category context" do
    group = Fabricate(:group)
    private_category = Fabricate(:private_category, group: group)
    user = Fabricate(:user)
    group.add(user)
    event.post.topic.update!(category: private_category)

    html = preview(user_id: user.id, category_id: private_category.id)

    expect(html.at_css(".discourse-event-onebox").text).to include(event.name)
  end

  it "escapes event names and locations" do
    event.update_columns(
      name: '<img src=x onerror="alert(1)">',
      location: "<script>alert(1)</script>",
    )

    html = preview

    expect(html.at_css(".discourse-event-onebox").text).to include(event.name)
    expect(html.css(".discourse-event-onebox img, .discourse-event-onebox script")).to be_empty
  end

  it "preserves calendar dates for all-day events" do
    event.update!(all_day: true)

    text = preview.at_css(".discourse-event-onebox").text

    expect(text).to include("September 20, 2026")
    expect(text).not_to include(event.timezone, "PM")
  end
end
