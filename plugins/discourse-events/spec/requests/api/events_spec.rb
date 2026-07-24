# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "events" do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  path "/discourse-post-event/events.json" do
    get "List calendar events" do
      tags "Discourse Calendar - Events"
      operationId "listEvents"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :include_details,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  enum: %w[true false],
                },
                description: "Include detailed event information (creator, invitees, stats, etc.)"

      parameter name: :category_id,
                in: :query,
                required: false,
                schema: {
                  type: :integer,
                },
                description: "Filter events by category ID"

      parameter name: :include_subcategories,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  enum: %w[true false],
                },
                description: "Include events from subcategories when filtering by category"

      parameter name: :post_id,
                in: :query,
                required: false,
                schema: {
                  type: :integer,
                },
                description: "Filter to events associated with a specific post ID"

      parameter name: :attending_user,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                },
                description:
                  "Filter to events where the specified user (username) has RSVP'd as going"

      parameter name: :before,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  format: "date-time",
                },
                description: "Return events starting before this date/time (ISO 8601 format)"

      parameter name: :after,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  format: "date-time",
                },
                description: "Return events starting after this date/time (ISO 8601 format)"

      parameter name: :order,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  enum: %w[asc desc],
                },
                description: "Sort order for events by start date (default: asc)"

      parameter name: :limit,
                in: :query,
                required: false,
                schema: {
                  type: :integer,
                  minimum: 1,
                  maximum: 200,
                },
                description: "Maximum number of events to return (default: 200)"

      produces "application/json"

      response "200", "success response (basic)" do
        expected_response_schema = load_spec_schema("events_index_response")
        schema expected_response_schema

        fab!(:event) { Fabricate(:event, original_starts_at: 1.day.from_now) }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end

      response "200", "success response (detailed)" do
        expected_response_schema = load_spec_schema("events_index_detailed_response")
        schema expected_response_schema

        fab!(:event) { Fabricate(:event, original_starts_at: 1.day.from_now) }

        let(:include_details) { "true" }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/discourse-post-event/events.ics" do
    get "Export calendar events in iCalendar format" do
      tags "Discourse Calendar - Events"
      operationId "exportEventsICS"
      consumes "application/json"
      expected_request_schema = nil

      parameter name: :category_id,
                in: :query,
                required: false,
                schema: {
                  type: :integer,
                },
                description: "Filter events by category ID"

      parameter name: :include_subcategories,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  enum: %w[true false],
                },
                description: "Include events from subcategories when filtering by category"

      parameter name: :attending_user,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                },
                description:
                  "Filter to events where the specified user (username) has RSVP'd as going"

      parameter name: :before,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  format: "date-time",
                },
                description: "Return events starting before this date/time (ISO 8601 format)"

      parameter name: :after,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  format: "date-time",
                },
                description: "Return events starting after this date/time (ISO 8601 format)"

      parameter name: :order,
                in: :query,
                required: false,
                schema: {
                  type: :string,
                  enum: %w[asc desc],
                },
                description: "Sort order for events by start date (default: asc)"

      parameter name: :limit,
                in: :query,
                required: false,
                schema: {
                  type: :integer,
                  minimum: 1,
                  maximum: 200,
                },
                description: "Maximum number of events to return (default: 200)"

      produces "text/calendar"

      response "200", "iCalendar file" do
        schema type: :string, format: "binary"

        fab!(:event) { Fabricate(:event, original_starts_at: 1.day.from_now, name: "Test Event") }

        before { |example| submit_request(example.metadata) }

        it "returns iCalendar format" do
          expect(response.status).to eq(200)
          expect(response.content_type).to include("text/calendar")
          expect(response.body).to include("BEGIN:VCALENDAR")
          expect(response.body).to include("END:VCALENDAR")
          expect(response.body).to include("BEGIN:VEVENT")
          expect(response.body).to include("END:VEVENT")
        end
      end
    end
  end
end
