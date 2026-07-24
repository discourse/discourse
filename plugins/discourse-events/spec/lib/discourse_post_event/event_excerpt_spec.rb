# frozen_string_literal: true

describe DiscoursePostEvent::EventExcerpt do
  def excerpt(post: nil, **attributes)
    fragment = Nokogiri::HTML5.fragment(<<~HTML)
      <p>intro</p>
      <div class="discourse-post-event"></div>
    HTML

    event_node = fragment.at_css(".discourse-post-event")
    attributes.each { |name, value| event_node["data-#{name.to_s.tr("_", "-")}"] = value }

    described_class.call(fragment, post: post)
    fragment.to_html
  end

  describe ".call" do
    it "replaces the event node with a summary of the start date" do
      html = excerpt(start: "2018-06-05 18:39:00")

      expect(html).to include("📅 June 5, 2018 6:39 PM (UTC)")
      expect(html).not_to include("discourse-post-event")
    end

    it "appends the end date when present" do
      html = excerpt(start: "2018-06-05 18:39:00", end: "2018-06-22 10:00:00")

      expect(html).to include("June 5, 2018 6:39 PM → June 22, 2018 10:00 AM (UTC)")
    end

    it "uses the event timezone" do
      html = excerpt(start: "2018-06-05 18:39:00", timezone: "America/New_York")

      expect(html).to include("June 5, 2018 6:39 PM (America/New_York)")
    end

    it "uses a date-only format without timezone for all-day events" do
      html = excerpt(start: "2018-06-05", all_day: "true")

      expect(html).to include("📅 June 5, 2018")
      expect(html).not_to include("(UTC)")
    end

    it "joins the name, dates, and location" do
      html = excerpt(name: "Pancakes", start: "2018-06-05 18:39:00", location: "Room A")

      expect(html).to include("📅 Pancakes · June 5, 2018 6:39 PM (UTC) · Room A")
    end

    it "omits the name when it matches the topic title" do
      post = Fabricate(:post)

      html = excerpt(post: post, name: post.topic.title, start: "2018-06-05 18:39:00")

      expect(html).not_to include(post.topic.title)
      expect(html).to include("📅 June 5, 2018 6:39 PM (UTC)")
    end

    it "escapes html in the event data" do
      html = excerpt(name: "Pancakes <b>bold</b>")

      expect(html).not_to include("<b>")
      expect(html).to include("Pancakes")
    end

    it "keeps unparseable dates as-is" do
      html = excerpt(start: "not-a-date")

      expect(html).to include("📅 not-a-date (UTC)")
    end

    it "removes the event node when there is nothing to summarize" do
      html = excerpt

      expect(html).not_to include("discourse-post-event")
      expect(html).not_to include("📅")
    end
  end
end
