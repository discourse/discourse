# frozen_string_literal: true

RSpec.describe Onebox::Engine::DiscourseTopicOnebox do
  subject(:onebox) { described_class.new(url) }

  describe "#data" do
    subject(:data) { onebox.data }

    let(:url) do
      "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483"
    end
    let(:expected_data) do
      {
        article_published_time: "6 Feb 14",
        article_published_time_title: "04:55AM - 06 February 2014",
        article_tags: %w[how-to sso],
        card: "summary",
        categories: [{ name: "praise", color: "9EB83B" }],
        data1: "1 mins 🕑",
        data2: "9 ❤",
        description:
          "Congratulations Discourse for qualifying Repositories with the most stars on GitHub Octoverse.     And that too in just over an year, way to go! 💥",
        domain: "Discourse Meta",
        favicon:
          "https://d11a6trkgmumsb.cloudfront.net/optimized/3X/b/3/b33be9538df3547fcf9d1a51a4637d77392ac6f9_2_32x32.png",
        ignore_canonical: "true",
        image:
          "https://d11a6trkgmumsb.cloudfront.net/optimized/2X/d/d063b3b0807377d98695ee08042a9ba0a8c593bd_2_690x362.png",
        label1: "Reading time",
        label2: "Likes",
        link:
          "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483",
        published_time: "2014-02-06T04:55:19+00:00",
        render_category_block?: true,
        render_tags?: true,
        site_name: "Discourse Meta",
        title: "Congratulations, most stars in 2013 GitHub Octoverse!",
        url:
          "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483",
      }
    end

    before do
      stub_request(:get, url).to_return(status: 200, body: onebox_response("discourse_topic"))
    end

    it "returns the expected data" do
      expect(data).to include expected_data
    end

    context "with Schema.org Event data" do
      let(:url) { "https://example.com/t/community-hangout/123" }
      let(:event_image_json) { %("image": "https://example.com/event.png",) }
      let(:event_description_json) { %("description": "Meet the community",) }
      let(:event_schedule_json) { "" }
      let(:html) { <<~HTML }
          <html>
            <head>
              <meta property="og:site_name" content="Example community">
              <meta property="og:title" content="Community hangout">
              <meta property="og:description" content="The ordinary topic excerpt">
              <meta property="og:image" content="https://example.com/site-logo.png">
              <meta property="og:image:width" content="1200">
              <meta property="og:image:height" content="630">
              <meta property="article:published_time" content="2026-10-19T00:00:00Z">
              <meta name="twitter:label1" value="Reading time">
              <meta name="twitter:data1" value="1 min 🕑">
              <meta name="twitter:label2" value="Likes">
              <meta name="twitter:data2" value="2 ❤">
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "Event",
                  "name": "Community hangout",
                  #{event_description_json}
                  #{event_image_json}
                  #{event_schedule_json}
                  "startDate": "2026-10-22T09:00:00.000-04:00",
                  "endDate": "2026-10-22T10:00:00.000-04:00"
                }
              </script>
            </head>
          </html>
        HTML

      before do
        freeze_time Time.utc(2026, 10, 20, 12)
        stub_request(:get, url).to_return(status: 200, body: html)
      end

      it "uses the event description and exposes event display data" do
        expect(data).to include(
          description: "Meet the community",
          is_event: true,
          event_all_day: false,
          event_date_day: "22",
          event_date_month: "Oct",
          event_onebox_classes: "discourse-event-onebox",
          event_starts_at: "2026-10-22T09:00:00.000-04:00",
          event_ends_at: "2026-10-22T10:00:00.000-04:00",
          event_timezone: "UTC-04:00",
        )
      end

      it "renders event data for client-side localization" do
        html = onebox.to_html

        expect(html).to include('class="discourse-event-onebox"')
        expect(html).not_to include("--banner-image")
        expect(html).to include('data-event-starts-at="2026-10-22T09:00:00.000-04:00"')
        expect(html).to include('class="discourse-event-onebox__date"')
        expect(html).to include("Meet the community")
        expect(html).not_to include("Reading time")
        expect(html).not_to include("Likes")
        expect(html).not_to include("The ordinary topic excerpt")
      end

      it "omits the post date from the header" do
        expect(data[:article_published_time]).to be_nil
        expect(onebox.to_html).to include(
          '<a href="https://example.com/t/community-hangout/123" target="_blank" rel="noopener">Example community</a>',
        )
      end

      it "does not render a recurrence for a one-off event" do
        expect(data[:event_recurrence]).to be_nil
        expect(onebox.to_html).not_to include("discourse-event-onebox__recurrence")
      end

      context "with a weekly schedule" do
        let(:event_schedule_json) { <<~JSON }
          "eventSchedule": {
            "@type": "Schedule",
            "repeatFrequency": "P1W",
            "byDay": "https://schema.org/Thursday",
            "endDate": "2026-12-31",
            "scheduleTimezone": "America/New_York"
          },
        JSON

        it "labels the recurrence and exposes it as a rule for finding later occurrences" do
          html = onebox.to_html

          expect(data[:event_recurrence]).to eq("Every Thursday until December 31, 2026")
          expect(html).to include(
            '<span class="discourse-event-onebox__recurrence-text">Every Thursday until December 31, 2026</span>',
          )
          expect(html).to include(
            'data-event-rrule="FREQ=WEEKLY;INTERVAL=1;BYDAY=TH;UNTIL=20261231T235959"',
          )
          expect(html).to include('data-event-schedule-timezone="America/New_York"')
        end
      end

      context "with a monthly schedule" do
        let(:event_schedule_json) { <<~JSON }
          "eventSchedule": { "repeatFrequency": "P1M", "byDay": "Thursday", "byMonthWeek": -1 },
        JSON

        it "labels the week of the month" do
          expect(data[:event_recurrence]).to eq("The last Thursday of every month")
          expect(data[:event_rrule]).to eq("FREQ=MONTHLY;BYDAY=-1TH")
        end
      end

      context "with a weekday schedule" do
        let(:event_schedule_json) { <<~JSON }
          "eventSchedule": {
            "repeatFrequency": "P1D",
            "byDay": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
          },
        JSON

        it "labels the weekdays" do
          expect(data[:event_recurrence]).to eq("Every weekday")
          expect(data[:event_rrule]).to eq("FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR")
        end
      end

      context "with a schedule that started long ago" do
        let(:event_schedule_json) { %("eventSchedule": { "repeatFrequency": "P1D" },) }

        before { freeze_time Time.utc(2028, 1, 1) }

        it "does not keep the schedule" do
          expect(data[:event_recurrence]).to be_nil
          expect(data[:event_rrule]).to be_nil
        end
      end

      context "with an unsupported schedule" do
        let(:event_schedule_json) { %("eventSchedule": { "repeatFrequency": "P3W" },) }

        it "does not label the recurrence" do
          expect(data[:event_recurrence]).to be_nil
          expect(data[:event_rrule]).to be_nil
        end
      end

      context "without an event description" do
        let(:event_description_json) { "" }

        it "does not fall back to the topic excerpt" do
          expect(data[:description]).to be_nil
          expect(onebox.to_html).not_to include('class="discourse-event-onebox__description"')
          expect(onebox.to_html).not_to include("The ordinary topic excerpt")
        end
      end

      it "uses the event's image rather than the page's" do
        expect(data[:image]).to eq("https://example.com/event.png")
        expect(onebox.to_html).not_to include("site-logo.png")
      end

      context "without an event image" do
        let(:event_image_json) { "" }

        it "does not fall back to the page's image" do
          expect(data[:image]).to be_nil
          expect(onebox.to_html).not_to include("<img")
        end
      end

      context "with a square event image" do
        let(:event_image_json) { image_object_json(500, 500) }

        it "letterboxes the image in the banner layout" do
          expect(data[:event_onebox_classes]).to eq(
            "discourse-event-onebox --banner-image --letterboxed-image",
          )
          expect(onebox.to_html).to include("--banner-image --letterboxed-image")
        end
      end

      context "with a portrait event image" do
        let(:event_image_json) { image_object_json(800, 1200) }

        it "uses the portrait image layout" do
          expect(data[:event_onebox_classes]).to eq("discourse-event-onebox --portrait-image")
          expect(onebox.to_html).to include("--portrait-image")
        end
      end

      context "with a 4:3 event image" do
        let(:event_image_json) { image_object_json(800, 600) }

        it "uses the banner image layout" do
          expect(data[:event_onebox_classes]).to eq("discourse-event-onebox --banner-image")
        end
      end

      context "with a landscape event image" do
        let(:event_image_json) { image_object_json(690, 362) }

        it "uses the banner image layout" do
          expect(data[:event_onebox_classes]).to eq("discourse-event-onebox --banner-image")
          expect(onebox.to_html).to include("--banner-image")
          expect(onebox.to_html).not_to include("--letterboxed-image")
        end
      end

      context "with an event image wider than 2:1" do
        let(:event_image_json) { image_object_json(1500, 500) }

        it "letterboxes the image in the banner layout" do
          expect(data[:event_onebox_classes]).to eq(
            "discourse-event-onebox --banner-image --letterboxed-image",
          )
        end
      end

      context "with image dimensions given as QuantitativeValues" do
        let(:event_image_json) { <<~JSON }
            "image": {
              "@type": "ImageObject",
              "url": "https://example.com/event.png",
              "width": { "@type": "QuantitativeValue", "value": 800 },
              "height": { "@type": "QuantitativeValue", "value": 1200 }
            },
          JSON

        it "reads the dimensions" do
          expect(data[:event_onebox_classes]).to eq("discourse-event-onebox --portrait-image")
        end
      end

      def image_object_json(width, height)
        <<~JSON
          "image": {
            "@type": "ImageObject",
            "url": "https://example.com/event.png",
            "width": #{width},
            "height": #{height}
          },
        JSON
      end
    end
  end
end
