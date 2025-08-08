# frozen_string_literal: true

describe DiscoursePostEvent::EventSummarySerializer do
  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Topic title :tada:") }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:event) { Fabricate(:event, post: post) }

  it "returns the event summary" do
    json = described_class.new(event, scope: Guardian.new).as_json
    summary = json[:event_summary]
    expect(summary[:starts_at]).to eq(event.starts_at)
    expect(summary[:ends_at]).to eq(event.ends_at)
    expect(summary[:timezone]).to eq(event.timezone)
    expect(summary[:name]).to eq(event.name)
    expect(summary[:post][:url]).to eq(post.url)
    expect(summary[:post][:topic][:title]).to eq("Topic title 🎉")
    expect(summary[:category_id]).to eq(category.id)
  end

  context "when recurrent event" do
    before { freeze_time Time.utc(2023, 1, 1, 1, 1) } # Sunday

    fab!(:post_2) { Fabricate(:post, topic: topic) }
    let(:every_day_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_day",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end

    it "returns the rrule" do
      json = described_class.new(every_day_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:rrule]).to eq(
        "FREQ=DAILY;BYHOUR=15;BYMINUTE=00;INTERVAL=1;WKST=MO",
      )
    end
  end

  describe "map_events_to_color" do
    context "when map_events_to_color is empty" do
      let(:json) do
        DiscoursePostEvent::EventSummarySerializer.new(event, scope: Guardian.new).as_json
      end

      it "returns the event summary with category_slug and tags" do
        summary = json[:event_summary]
        expect(summary[:post][:topic][:category_slug]).to be_nil
        expect(summary[:post][:topic][:tags]).to be_nil
      end
    end

    context "when map_events_to_color is set" do
      let(:json) do
        DiscoursePostEvent::EventSummarySerializer.new(event, scope: Guardian.new).as_json
      end

      before do
        SiteSetting.map_events_to_color = [
          { type: "tag", color: "#21d939", slug: "nice-tag" },
        ].to_json
      end

      it "returns the event summary with category_slug and tags" do
        summary = json[:event_summary]
        expect(summary[:post][:topic][:category_slug]).to eq(category.slug)
        expect(summary[:post][:topic][:tags]).to eq(topic.tags.map(&:name))
      end
    end
  end
end
