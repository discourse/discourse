# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class MergedTopicsController < JsonApiKit::BaseController
    resource :topics
  end

  class MergeTopicsPostedDateAndTimeIntoPostedAt < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `posted_date` and `posted_time` attributes of the topics resource become `posted_at`."

    resource :topics do
      merged_attributes from: %i[posted_date posted_time],
                        to: :posted_at,
                        up: ->(date, time) { Time.zone.parse("#{date} #{time}") },
                        down: ->(posted_at) do
                          next nil, nil if posted_at.nil?
                          [posted_at.to_date.iso8601, posted_at.strftime("%H:%M:%S")]
                        end
    end
  end

  class RenameMergedTopicsPostedAtToCreatedAt < JsonApiKit::VersionChange
    version "2026-10-01"
    description "The `posted_at` attribute of the topics resource is renamed to `created_at`."

    resource :topics do
      renamed_attribute from: :posted_at, to: :created_at
    end
  end
end

RSpec.describe "JSON:API merged attributes", type: :request do
  include_context "with a listing of topics"

  let(:first_version) { JsonApiKit::Timeline::FIRST_RELEASE }
  let(:merge) { JsonApiKitSpec::MergeTopicsPostedDateAndTimeIntoPostedAt.new(__FILE__) }
  let(:rename) { JsonApiKitSpec::RenameMergedTopicsPostedAtToCreatedAt.new(__FILE__) }
  let(:version_changes) { JsonApiKit::VersionChanges.new([merge, rename]) }
  let(:version) { first_version.to_s }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:error) { parsed_body["errors"].sole }
  let(:attributes) { parsed_body["data"].first["attributes"] }
  let(:ids) { parsed_body["data"].map { it["id"] } }

  before do
    freeze_time(rename.version.date + 1.day)
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/merged-topics" => "json_api_kit_spec/merged_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/merged-topics", headers: { "HTTP_API_VERSION" => version }, params: query
  end

  after { Rails.application.reload_routes! }

  context "when the client is pinned before the merge" do
    it "sends the attributes under the names of that version" do
      expect(attributes.keys).to contain_exactly("title", "postedDate", "postedTime")
    end

    it "sends the merged attribute as the two values of that version" do
      expect(attributes.slice("postedDate", "postedTime")).to eq(
        "postedDate" => "2026-08-03",
        "postedTime" => "00:00:00",
      )
    end

    context "when the request selects one of the merged fields" do
      let(:query) { { "fields" => { "topics" => "postedDate" } } }

      it "sends that field only" do
        expect(attributes.keys).to contain_exactly("postedDate")
      end
    end

    context "when the request selects both merged fields" do
      let(:query) { { "fields" => { "topics" => "postedDate,postedTime" } } }

      it "sends those fields only" do
        expect(attributes.keys).to contain_exactly("postedDate", "postedTime")
      end
    end

    context "when the request sorts by one of the merged fields" do
      let(:query) { { "sort" => "postedDate" } }

      it "orders the rows by the merged attribute" do
        expect(ids).to eq([oldest.id.to_s, middle.id.to_s, newest.id.to_s])
      end
    end

    context "when the request sorts by both merged fields in one direction" do
      let(:query) { { "sort" => "postedDate,postedTime" } }

      it "orders the rows by the merged attribute" do
        expect(ids).to eq([oldest.id.to_s, middle.id.to_s, newest.id.to_s])
      end
    end

    context "when the request sorts by both merged fields in two directions" do
      let(:query) { { "sort" => "postedDate,-postedTime" } }

      it "sends a refusal with both field names" do
        expect(error).to eq(
          refusal(
            title: "Invalid sort",
            detail: "postedDate and postedTime sort by one attribute in two directions.",
            parameter: "sort",
          ).deep_stringify_keys,
        )
      end
    end

    context "when the request anchors a window on the merged fields" do
      let(:query) do
        {
          "sort" => "postedDate",
          "page" => {
            "anchor" => {
              "postedDate" => "2026-08-02",
              "postedTime" => "00:00:00",
            },
            "beforeSize" => "1",
            "afterSize" => "0",
          },
        }
      end

      it "sends the rows of the window" do
        expect(ids).to eq([oldest.id.to_s, middle.id.to_s])
      end
    end

    context "when the anchor holds a value this version cannot convert" do
      let(:query) do
        {
          "sort" => "postedDate",
          "page" => {
            "anchor" => {
              "postedDate" => "2026-13-45",
              "postedTime" => "00:00:00",
            },
            "beforeSize" => "1",
          },
        }
      end

      it "sends a refusal on the anchor parameter" do
        expect(error).to eq(
          refusal(
            title: "Invalid value",
            detail: "This version cannot convert the value of postedDate, postedTime.",
            parameter: "page[anchor]",
          ).deep_stringify_keys,
        )
      end
    end

    context "when a refusal includes the merged field" do
      let(:query) do
        {
          "sort" => "title",
          "page" => {
            "anchor" => {
              "postedDate" => "2026-08-02",
              "postedTime" => "00:00:00",
            },
          },
        }
      end

      it "sends the first name of that version" do
        expect(error).to eq(
          refusal(
            title: "Anchor does not match the sort",
            detail: "The anchor is postedDate, but this request sorts by title.",
            parameter: "page[anchor][postedDate]",
          ).deep_stringify_keys,
        )
      end
    end
  end

  context "when the client is pinned between the merge and the rename" do
    let(:version) { merge.version.to_s }

    it "sends the attributes under the names of that version" do
      expect(attributes.keys).to contain_exactly("title", "postedAt")
    end
  end

  context "when the client is pinned at the rename" do
    let(:version) { rename.version.to_s }
    let(:query) { { "fields" => { "topics" => "createdAt" } } }

    it "sends the field it selects" do
      expect(attributes.keys).to contain_exactly("createdAt")
    end
  end
end
