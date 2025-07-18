# frozen_string_literal: true
require "rails_helper"

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
    let(:every_week_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_week",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_two_weeks_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_two_weeks",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_four_weeks_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_four_weeks",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_month_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_month",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end
    let(:every_weekday_event) do
      Fabricate(
        :event,
        post: post_2,
        recurrence: "every_weekday",
        original_starts_at: "2023-01-01 15:00",
        original_ends_at: "2023-01-01 16:00",
      )
    end

    it "returns next dates for the every day event" do
      json = described_class.new(every_day_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(365)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-31 15:00:00.000000000 +0000",
          ends_at: "2023-12-31 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every week event" do
      json = described_class.new(every_week_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(52)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-24 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-24 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every two weeks event" do
      json = described_class.new(every_two_weeks_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(26)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-17 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-17 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every four weeks event" do
      json = described_class.new(every_four_weeks_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(13)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-03 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-03 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every weekday event" do
      json = described_class.new(every_weekday_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(260)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-29 15:00:00.000000000 +0000", # Friday
          ends_at: "2023-12-29 16:00:00.000000000 +0000",
        },
      )
    end

    it "returns next dates for the every month event" do
      json = described_class.new(every_month_event, scope: Guardian.new).as_json
      expect(json[:event_summary][:upcoming_dates].length).to eq(12)
      expect(json[:event_summary][:upcoming_dates].last).to eq(
        {
          starts_at: "2023-12-03 15:00:00.000000000 +0000", # Sunday
          ends_at: "2023-12-03 16:00:00.000000000 +0000",
        },
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
