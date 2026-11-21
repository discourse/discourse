# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::OneboxOccurrence do
  def onebox_html(
    starts_at:,
    ends_at: nil,
    all_day: false,
    src: "https://other.example.com/t/1",
    rrule: nil,
    timezone: "America/New_York"
  )
    <<~HTML
      <aside class="onebox discoursetopic_with_event" data-onebox-src="#{src}">
        <div class="discourse-event-onebox"
             data-event-all-day="#{all_day}"
             data-event-starts-at="#{starts_at}"
             data-event-ends-at="#{ends_at}"
             data-event-rrule="#{rrule}"
             data-event-schedule-timezone="#{timezone}">
          <time class="discourse-event-onebox__date" datetime="#{starts_at}">
            <span class="discourse-event-onebox__month">Oct</span>
            <span class="discourse-event-onebox__day">22</span>
          </time>
          <span class="discourse-event-onebox__time-text">9:00 AM → 10:00 AM (UTC-04:00)</span>
        </div>
      </aside>
    HTML
  end

  def current(**options)
    node = Nokogiri::HTML5.fragment(onebox_html(**options)).at_css(".discourse-event-onebox")
    described_class.new(node).current
  end

  let(:weekly) do
    {
      starts_at: "2026-10-22T09:00:00.000-04:00",
      ends_at: "2026-10-22T10:00:00.000-04:00",
      rrule: "FREQ=WEEKLY;INTERVAL=1;BYDAY=TH",
    }
  end

  describe "#current" do
    it "moves on to the upcoming occurrence at the same wall-clock time across DST" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(current(**weekly)).to eq(
        starts_at: "2026-11-12T09:00:00.000-05:00",
        ends_at: "2026-11-12T10:00:00.000-05:00",
      )
    end

    it "keeps an occurrence that is still underway" do
      freeze_time Time.utc(2026, 10, 22, 13, 30)

      expect(current(**weekly)).to be_nil
    end

    it "stops at the final occurrence of the series" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(
        current(**weekly, rrule: "FREQ=WEEKLY;INTERVAL=1;BYDAY=TH;UNTIL=20261101T235959"),
      ).to include(starts_at: "2026-10-29T09:00:00.000-04:00")
    end

    it "keeps the week of the month for a monthly event" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(
        current(starts_at: "2026-10-29T09:00:00.000-04:00", rrule: "FREQ=MONTHLY;BYDAY=-1TH"),
      ).to include(starts_at: "2026-11-26T09:00:00.000-05:00")
    end

    it "skips weekends for a weekday event" do
      freeze_time Time.utc(2026, 10, 24, 12)

      expect(
        current(
          starts_at: "2026-10-23T09:00:00.000-04:00",
          rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
        ),
      ).to include(starts_at: "2026-10-26T09:00:00.000-04:00")
    end

    it "keeps alternate weeks for a fortnightly event" do
      freeze_time Time.utc(2027, 6, 1, 12)

      expect(current(**weekly, rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TH")).to include(
        starts_at: "2027-06-03T09:00:00.000-04:00",
      )
    end

    it "catches up on a daily event fetched years ago" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(current(starts_at: "2020-01-01T09:00:00.000-05:00", rrule: "FREQ=DAILY")).to include(
        starts_at: "2026-11-10T09:00:00.000-05:00",
      )
    end

    it "skips ahead from an ancient start rather than stepping through every occurrence" do
      freeze_time Time.utc(2026, 11, 10, 12)
      dtstarts = []
      allow(RRule::Rule).to receive(:new).and_wrap_original do |original, pattern, **options|
        dtstarts << options[:dtstart]
        original.call(pattern, **options)
      end

      expect(
        current(
          starts_at: "1000-01-01T09:00:00.000+00:00",
          rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=WE",
          timezone: "UTC",
        ),
      ).to include(starts_at: "2026-11-18T09:00:00.000Z")
      expect(dtstarts).to all(be > Time.utc(2026, 9, 1))
    end

    it "skips ahead to the final occurrence of a series that ended long ago" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(
        current(
          starts_at: "1000-01-01T09:00:00.000+00:00",
          rrule: "FREQ=WEEKLY;INTERVAL=4;BYDAY=WE;UNTIL=20200101T235959",
          timezone: "UTC",
        ),
      ).to include(starts_at: "2019-12-25T09:00:00.000Z")
    end

    it "ignores rules the onebox doesn't write" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(current(**weekly, rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TH;COUNT=100000")).to be_nil
      expect(current(**weekly, rrule: "FREQ=SECONDLY")).to be_nil
    end

    it "moves an all-day event by whole days once its day is over" do
      freeze_time Time.utc(2026, 10, 23, 12)

      expect(
        current(
          all_day: true,
          starts_at: "2026-10-22",
          ends_at: "2026-10-22",
          rrule: "FREQ=WEEKLY;INTERVAL=1;BYDAY=TH",
          timezone: "",
        ),
      ).to eq(starts_at: "2026-10-29", ends_at: "2026-10-29")
    end

    it "ignores a malformed rule" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(current(**weekly, rrule: "FREQ=SOMETIMES")).to be_nil
    end

    it "ignores one-off events" do
      freeze_time Time.utc(2026, 11, 10, 12)

      expect(current(**weekly, rrule: "")).to be_nil
    end
  end

  describe ".for_cooked" do
    it "keys the occurrences that have moved on by onebox source" do
      freeze_time Time.utc(2026, 11, 10, 12)
      cooked =
        onebox_html(**weekly) + onebox_html(**weekly, rrule: "", src: "https://one-off.example.com")

      expect(described_class.for_cooked(cooked)).to eq(
        "https://other.example.com/t/1" => {
          starts_at: "2026-11-12T09:00:00.000-05:00",
          ends_at: "2026-11-12T10:00:00.000-05:00",
        },
      )
    end

    it "skips cooked content without event oneboxes" do
      allow(Nokogiri::HTML5).to receive(:fragment).and_call_original

      expect(described_class.for_cooked("<p>Hello</p>")).to eq({})
      expect(Nokogiri::HTML5).not_to have_received(:fragment)
    end
  end

  describe "#apply!" do
    it "rewrites the onebox to show the upcoming occurrence" do
      freeze_time Time.utc(2026, 11, 10, 12)
      fragment = Nokogiri::HTML5.fragment(onebox_html(**weekly))
      described_class.new(fragment.at_css(".discourse-event-onebox")).apply!

      expect(fragment.at_css(".discourse-event-onebox__date")["datetime"]).to eq(
        "2026-11-12T09:00:00.000-05:00",
      )
      expect(fragment.at_css(".discourse-event-onebox__month").text).to eq("Nov")
      expect(fragment.at_css(".discourse-event-onebox__day").text).to eq("12")
      expect(fragment.at_css(".discourse-event-onebox__time-text").text).to eq(
        "9:00 AM → 10:00 AM (UTC-05:00)",
      )
    end
  end

  describe "in the post serializer" do
    fab!(:post)

    before do
      SiteSetting.discourse_events_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    it "includes the occurrences that have moved on" do
      freeze_time Time.utc(2026, 11, 10, 12)
      post.update_columns(cooked: onebox_html(**weekly))

      json = PostSerializer.new(post, scope: Guardian.new, root: false).as_json

      expect(json[:event_onebox_occurrences]).to eq(
        "https://other.example.com/t/1" => {
          starts_at: "2026-11-12T09:00:00.000-05:00",
          ends_at: "2026-11-12T10:00:00.000-05:00",
        },
      )
    end

    it "omits them for posts without event oneboxes" do
      json = PostSerializer.new(post, scope: Guardian.new, root: false).as_json

      expect(json).not_to have_key(:event_onebox_occurrences)
    end
  end

  describe "in emails" do
    before do
      SiteSetting.discourse_events_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    it "shows the upcoming occurrence" do
      freeze_time Time.utc(2026, 11, 10, 12)

      html = PrettyText.format_for_email(onebox_html(**weekly))

      expect(html).to include('<span class="discourse-event-onebox__day">12</span>')
    end
  end
end
