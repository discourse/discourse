# frozen_string_literal: true

describe PrettyText do
  before do
    freeze_time Time.utc(2018, 6, 5, 18, 40)

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "with a public event" do
    describe "An event is displayed in an email" do
      let(:user_1) { Fabricate(:user, admin: true) }

      context "when the event has no name" do
        let(:post_1) { create_post_with_event(user_1) }

        it "displays the topic title" do
          cooked = PrettyText.cook(post_1.raw)

          expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
            <div style='border:1px solid #dedede'>
              <p><a href="#{Discourse.base_url}#{post_1.url}">#{post_1.topic.title}</a></p>
              <p>2018-06-05T18:39:50.000Z (UTC)</p>
            </div>
          HTML
        end
      end

      context "when the event has a name" do
        let(:post_1) { create_post_with_event(user_1, 'name="Pancakes event"') }
        let(:post_2) do
          create_post_with_event(user_1, 'name="Pancakes event <a>with html chars</a>"')
        end

        it "displays the event name" do
          cooked = PrettyText.cook(post_1.raw)

          expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
            <div style='border:1px solid #dedede'>
              <p><a href="#{Discourse.base_url}#{post_1.url}">Pancakes event</a></p>
              <p>2018-06-05T18:39:50.000Z (UTC)</p>
            </div>
          HTML
        end

        it "properly escapes title" do
          cooked = PrettyText.cook(post_2.raw)

          expect(PrettyText.format_for_email(cooked, post_2)).to match_html(<<~HTML)
            <div style='border:1px solid #dedede'>
              <p><a href="#{Discourse.base_url}#{post_2.url}">Pancakes event &lt;a&gt;with html chars&lt;/a&gt;</a></p>
              <p>2018-06-05T18:39:50.000Z (UTC)</p>
            </div>
          HTML
        end
      end

      context "when the event has an end date" do
        let(:post_1) { create_post_with_event(user_1, 'end="2018-06-22"') }

        it "displays the end date" do
          cooked = PrettyText.cook(post_1.raw)

          expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
            <div style='border:1px solid #dedede'>
              <p><a href="#{Discourse.base_url}#{post_1.url}">#{post_1.topic.title}</a></p>
              <p>2018-06-05T18:39:50.000Z (UTC) → 2018-06-22 (UTC)</p>
            </div>
          HTML
        end
      end

      context "when the event has a timezone" do
        let(:post_1) { create_post_with_event(user_1, 'timezone="America/New_York"') }

        it "uses the timezone" do
          cooked = PrettyText.cook(post_1.raw)

          expect(PrettyText.format_for_email(cooked, post_1)).to match_html(<<~HTML)
            <div style='border:1px solid #dedede'>
              <p><a href="#{Discourse.base_url}#{post_1.url}">#{post_1.topic.title}</a></p>
              <p>2018-06-05T18:39:50.000Z (America/New_York)</p>
            </div>
          HTML
        end
      end
    end
  end
end
