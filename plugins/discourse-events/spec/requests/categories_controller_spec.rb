# frozen_string_literal: true

describe CategoriesController do
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    DiscourseEvents::Categories::Types::Events.configure_category(
      category,
      guardian: admin.guardian,
    )
    sign_in(admin)
  end

  describe "#index" do
    it "includes event dates on featured topics" do
      freeze_time(Time.utc(2020, 4, 24, 14, 10))
      Jobs.run_immediately!
      topic = Fabricate(:topic, category:)
      post = Fabricate(:post, topic:)
      DiscourseEvents::Events::Event.create!(
        id: post.id,
        original_starts_at: 1.hour.from_now,
        original_ends_at: 2.hours.from_now,
      )
      CategoryFeaturedTopic.feature_topics

      get "/categories.json?include_topics=true"

      expect(response.status).to eq(200)
      categories = response.parsed_body["category_list"]["categories"]
      serialized_category = categories.find { |serialized| serialized["id"] == category.id }
      expect(serialized_category["topics"]).to include(
        a_hash_including(
          "id" => topic.id,
          "event_starts_at" => "2020-04-24T15:10:00.000Z",
          "event_ends_at" => "2020-04-24T16:10:00.000Z",
        ),
      )
    end
  end

  describe "#update" do
    it "persists category_type_settings into calendar_categories" do
      put "/categories/#{category.id}.json",
          params: {
            category_type_settings: {
              events_calendar_default_view: "week",
              events_calendar_display_weekends: false,
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "leaves calendar_categories untouched when category_type_settings is absent" do
      original = SiteSetting.calendar_categories

      put "/categories/#{category.id}.json", params: { name: "Renamed Events" }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to eq(original)
    end

    it "preserves unspecified category_type_settings when only one key is sent" do
      DiscourseEvents::Categories::Types::Events.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "year",
          events_calendar_display_weekends: false,
        },
      )

      put "/categories/#{category.id}.json",
          params: {
            category_type_settings: {
              events_calendar_default_view: "week",
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "persists site setting edits via category_type_site_settings" do
      put "/categories/#{category.id}.json",
          params: {
            category_type_site_settings: {
              sidebar_show_upcoming_events: false,
            },
          }

      expect(response.status).to eq(200)
      expect(SiteSetting.sidebar_show_upcoming_events).to eq(false)
    end
  end
end
