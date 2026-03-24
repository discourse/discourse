# frozen_string_literal: true

describe PrettyText do
  before do
    freeze_time Time.utc(2018, 6, 5, 18, 40)

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "with a public event" do
    describe "An event is displayed in an email" do
      fab!(:user_1, :user) { Fabricate(:user, admin: true) }

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

        it "displays the location" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include("Conference Room A")
        end
      end

      context "when the event has a url" do
        let(:post_1) { create_post_with_event(user_1, 'url="https://example.com/meeting"') }

        it "displays the url" do
          cooked = PrettyText.cook(post_1.raw)
          result = PrettyText.format_for_email(cooked, post_1)

          expect(result).to include('href="https://example.com/meeting"')
          expect(result).to include("https://example.com/meeting")
        end
      end
    end
  end
end
