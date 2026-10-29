# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:admin)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_event_schema_for_topics = true
  end

  describe "#show" do
    let(:post) { PostCreator.create!(admin, title: "Community hangout", raw: <<~RAW) }
        [event start="2026-10-22T13:00:00.000Z" end="2026-10-22T14:00:00.000Z" timezone="America/New_York" location="Town hall"]
        Meet **the community**
        [/event]
      RAW

    it "does not publish event schema when disabled" do
      SiteSetting.enable_event_schema_for_topics = false

      get post.topic.url

      expect(response.status).to eq(200)
      expect(response.body).not_to include('"@type":"Event"')
    end

    it "publishes event schema for ordinary and crawler HTML requests" do
      [nil, "Googlebot"].each do |user_agent|
        headers = user_agent ? { "HTTP_USER_AGENT" => user_agent } : {}
        get post.topic.url, headers: headers

        expect(response.status).to eq(200)
        script =
          Nokogiri
            .HTML5(response.body)
            .css('script[type="application/ld+json"]')
            .find { |element| element.text.include?('"@type":"Event"') }
        expect(script).to be_present, "missing Event schema for #{user_agent || "ordinary request"}"
        schema = JSON.parse(script.text)
        expect(schema).to include(
          "@context" => "https://schema.org",
          "@type" => "Event",
          "name" => "Community hangout",
          "description" => "Meet the community",
          "startDate" => "2026-10-22T09:00:00.000-04:00",
          "endDate" => "2026-10-22T10:00:00.000-04:00",
        )
      end
    end
  end
end
