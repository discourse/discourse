# frozen_string_literal: true

describe PrettyText do
  before do
    freeze_time Time.utc(2018, 6, 5, 18, 40)

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "with a public event" do
    describe "An event is displayed in an email" do
      fab!(:user_1, :user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }

      context "when the event has no name" do
        let(:post_1) { create_post_with_event(user_1) }

        it "displays the topic title with formatted date" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include(post_1.topic.title)
          expect(result).to include("June 5, 2018 6:39 PM (UTC)")
          expect(result).to include("table")
        end
      end

      context "when the event has a name" do
        let(:post_1) { create_post_with_event(user_1, 'name="Pancakes event"') }
        let(:post_2) do
          create_post_with_event(user_1, 'name="Pancakes event <a>with html chars</a>"')
        end

        it "displays the event name" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Pancakes event")
          expect(result).to include("font-weight: bold")
        end

        it "properly escapes title" do
          cooked = PrettyText.cook(post_2.raw)
          result = PrettyText.format_for_email(cooked, post_2)

          expect(result).to include("Pancakes event &lt;a&gt;with html chars&lt;/a&gt;")
        end

        it "renders emoji in the name (matching the on-site card)" do
          post = create_post_with_event(user_1, 'name="Launch :rocket:"')

          cooked = PrettyText.cook(post.raw)
          result = PrettyText.format_for_email(cooked, post)

          expect(result).to include("🚀")
          expect(result).not_to include(":rocket:")
        end
      end

      context "when the event has an end date" do
        let(:post_1) { create_post_with_event(user_1, 'end="2018-06-22"') }

        it "displays the formatted end date" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("June 5, 2018 6:39 PM (UTC)")
          expect(result).to include("→")
          expect(result).to include("June 22, 2018 12:00 AM (UTC)")
        end
      end

      context "when the event has a timezone" do
        let(:post_1) { create_post_with_event(user_1, 'timezone="America/New_York"') }

        it "uses the timezone" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("(America/New_York)")
          expect(result).to include("June 5, 2018 6:39 PM")
        end
      end

      context "when the event has a location" do
        let(:post_1) { create_post_with_event(user_1, 'location="Conference Room A"') }
        let(:post_2) { create_post_with_event(user_1, 'location="https://maps.example.com"') }

        it "displays the location" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Conference Room A")
        end

        it "cooks links in the location (matching the on-site card)" do
          cooked = PrettyText.cook(post_2.raw)
          result = PrettyText.format_for_email(cooked, post_2)

          expect(result).to include('href="https://maps.example.com"')
        end
      end

      context "when the event has a url" do
        let(:post_1) { create_post_with_event(user_1, 'url="https://example.com/meeting"') }
        let(:post_2) { create_post_with_event(user_1, 'url="example.com"') }

        it "displays the url" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include('href="https://example.com/meeting"')
          expect(result).to include("https://example.com/meeting")
        end

        it "prepends a scheme to a scheme-less url so the link is absolute" do
          cooked = PrettyText.cook(post_2.raw)
          result = PrettyText.format_for_email(cooked, post_2)

          expect(result).to include('href="https://example.com"')
          expect(result).to include(">example.com</a>")
        end

        it "makes a url with a non-web scheme absolute" do
          post_3 = create_post_with_event(user_1, 'url="ftp://files.example.com"')
          cooked = PrettyText.cook(post_3.raw)
          result = PrettyText.format_for_email(cooked, post_3)

          expect(result).to include('href="https://ftp://files.example.com"')
        end
      end

      context "when the event has an image" do
        fab!(:upload)
        let(:post_1) { create_post_with_event(user_1, "image=\"#{upload.short_url}\"") }

        it "displays the image" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("<img")
          expect(result).to include(upload.url)
        end
      end

      context "when the event has a description" do
        let(:post_1) do
          start = (Time.now - 10.seconds).utc.iso8601(3)
          PostCreator.create!(
            user_1,
            title: "Sell a boat party ##{SecureRandom.alphanumeric}",
            raw:
              "[event start=\"#{start}\"]\nJoin us at https://example.com\nfor pancakes\n[/event]",
          ).reload
        end

        it "displays the description with links and line breaks" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Join us at")
          expect(result).to include('href="https://example.com"')
          expect(result).to include("<br")
          expect(result).to include("for pancakes")
        end

        it "escapes html in the description" do
          post_1.event.update!(description: "Tom & Jerry <script>alert(1)</script>")

          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Tom &amp; Jerry &lt;script&gt;")
          expect(result).not_to include("<script>")
        end
      end

      context "when the event is all-day" do
        let(:post_1) do
          PostCreator.create!(
            user_1,
            title: "Sell a boat party ##{SecureRandom.alphanumeric}",
            raw: "[event start=\"2018-06-05\" all-day=\"true\"]\n[/event]",
          ).reload
        end

        it "displays the date without a time or timezone" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("June 5, 2018")
          expect(result).not_to include("12:00 AM")
          expect(result).not_to include("(UTC)")
        end
      end

      context "when the event recurs" do
        let(:post_1) { create_post_with_event(user_1, 'recurrence="every_week"') }
        let(:post_2) { create_post_with_event(user_1, 'recurrence="every_month"') }

        it "displays the weekly recurrence" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Every Tuesday")
        end

        it "displays the monthly recurrence with its ordinal" do
          cooked = PrettyText.cook(post_2.raw)
          result = PrettyText.format_for_email(cooked, post_2)

          expect(result).to include("The first Tuesday of every month")
        end
      end

      context "when the event is closed" do
        let(:post_1) { create_post_with_event(user_1, 'status="public" closed="true"') }

        it "displays the closed status" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Closed")
        end
      end

      context "with the event creator" do
        let(:post_1) { create_post_with_event(user_1) }

        it "displays who created the event" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Created by")
          expect(result).to include(user_1.display_name)
        end

        it "shows the username instead of the name when names are disabled" do
          SiteSetting.enable_names = false
          user_1.update!(name: "Top Secret Name")

          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include(user_1.username)
          expect(result).not_to include("Top Secret Name")
        end
      end

      context "when the event has attendees" do
        let(:post_1) { create_post_with_event(user_1, 'status="public"') }

        it "displays the going count" do
          DiscoursePostEvent::Invitee.create!(
            post_id: post_1.id,
            user_id: Fabricate(:user).id,
            status: DiscoursePostEvent::Invitee.statuses[:going],
          )

          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("1 going")
        end

        it "displays a zero going count when there are no attendees" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("0 going")
        end
      end

      context "when the event is a standalone event" do
        let(:post_1) { create_post_with_event(user_1, 'status="standalone"') }

        it "does not display a going count" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).not_to include("going")
        end
      end

      context "when the event is expired and recurring" do
        let(:post_1) do
          PostCreator.create!(
            user_1,
            title: "Sell a boat party ##{SecureRandom.alphanumeric}",
            raw:
              "[event start=\"2018-05-01 10:00\" recurrence=\"every_week\" recurrence-until=\"2018-05-20 10:00\"]\n[/event]",
          ).reload
        end

        it "does not display a stale date (matching the on-site card)" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).not_to include("May 1, 2018")
          expect(result).to include(">-</td>")
        end
      end

      context "when the renderer raises" do
        let(:post_1) { create_post_with_event(user_1) }

        it "does not abort the rest of the email rendering" do
          cooked = PrettyText.cook(post_1.raw)
          DiscoursePostEvent::EmailRenderer.stubs(:render).raises(StandardError.new("boom"))

          expect { PrettyText.format_for_email(cooked, post_1) }.not_to raise_error
        end
      end
    end

    describe "An event is summarized in an excerpt (used by oneboxes)" do
      fab!(:user_1, :user) { Fabricate(:user, admin: true) }

      def excerpt_for(post)
        PrettyText.excerpt(post.cooked, SiteSetting.post_onebox_maxlength, post: post)
      end

      it "summarizes the event with its formatted start date" do
        excerpt = excerpt_for(create_post_with_event(user_1))

        expect(excerpt).to include("📅")
        expect(excerpt).to include("June 5, 2018 6:39 PM (UTC)")
      end

      it "includes the end date when present" do
        excerpt = excerpt_for(create_post_with_event(user_1, 'end="2018-06-22"'))

        expect(excerpt).to include("→")
        expect(excerpt).to include("June 22, 2018 12:00 AM (UTC)")
      end

      it "uses the event timezone" do
        excerpt = excerpt_for(create_post_with_event(user_1, 'timezone="America/New_York"'))

        expect(excerpt).to include("(America/New_York)")
      end

      it "includes the location" do
        excerpt = excerpt_for(create_post_with_event(user_1, 'location="Conference Room A"'))

        expect(excerpt).to include("Conference Room A")
      end

      it "includes the event name when it differs from the topic title" do
        excerpt = excerpt_for(create_post_with_event(user_1, 'name="Pancakes event"'))

        expect(excerpt).to include("Pancakes event")
      end

      it "escapes html in the event data" do
        excerpt = excerpt_for(create_post_with_event(user_1, 'name="Pancakes <b>bold</b>"'))

        expect(excerpt).not_to include("<b>")
      end

      it "does nothing when the plugin is disabled" do
        post = create_post_with_event(user_1)
        SiteSetting.discourse_post_event_enabled = false

        expect(excerpt_for(post)).not_to include("📅")
      end
    end
  end
end
