# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class ChangedTopicsController < JsonApiKit::BaseController
    resource :topics
  end

  class RenameTopicsPostedAtToCreatedAt < JsonApiKit::VersionChange
    version "2026-10-01"
    description "The `posted_at` attribute of the topics resource is renamed to `created_at`."

    resource :topics do
      renamed_attribute from: :posted_at, to: :created_at
    end
  end
end

RSpec.describe "JSON:API version changes", type: :request do
  include_context "with a listing of topics"

  let(:first_version) { JsonApiKit::Timeline::FIRST_RELEASE }
  let(:change) { JsonApiKitSpec::RenameTopicsPostedAtToCreatedAt.new(__FILE__) }
  let(:change_version) { change.version }
  let(:version) { first_version.to_s }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:error) { parsed_body["errors"].sole }
  let(:attributes) { parsed_body["data"].first["attributes"] }
  let(:ids) { parsed_body["data"].map { it["id"] } }

  before do
    freeze_time(change_version.date + 1.day)
    allow(JsonApiKit::VersionChange).to receive(:all).and_return([change])
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/changed-topics" => "json_api_kit_spec/changed_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/changed-topics", headers: { "HTTP_API_VERSION" => version }, params: query
  end

  after { Rails.application.reload_routes! }

  context "when the client is pinned before the change" do
    it "sends the version of the pin" do
      expect(response.headers["Api-Version"]).to eq(first_version.to_s)
    end

    it "sends the attributes under the names of that version" do
      expect(attributes.keys).to contain_exactly("title", "postedAt")
    end

    context "when the request selects the renamed field" do
      let(:query) { { "fields" => { "topics" => "postedAt" } } }

      it "sends that field only" do
        expect(attributes.keys).to contain_exactly("postedAt")
      end
    end

    context "when the request sorts by the renamed field" do
      let(:query) { { "sort" => "postedAt" } }

      it "orders the rows by that attribute" do
        expect(ids).to eq([oldest.id.to_s, middle.id.to_s, newest.id.to_s])
      end
    end

    context "when the request anchors a window on the renamed field" do
      let(:query) do
        {
          "sort" => "postedAt",
          "page" => {
            "anchor" => {
              "postedAt" => middle.created_at.iso8601(6),
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

    context "when a refusal includes the renamed field" do
      let(:query) do
        {
          "sort" => "title",
          "page" => {
            "anchor" => {
              "postedAt" => middle.created_at.iso8601(6),
            },
          },
        }
      end

      it "sends the name of that version" do
        expect(error).to eq(
          refusal(
            title: "Anchor does not match the sort",
            detail: "The anchor is postedAt, but this request sorts by title.",
            parameter: "page[anchor][postedAt]",
          ).deep_stringify_keys,
        )
      end
    end

    context "when the request uses the new name" do
      let(:query) { { "fields" => { "topics" => "createdAt" } } }

      it { expect(response).to have_http_status(:bad_request) }

      it "sends the reason" do
        expect(error).to eq(
          refusal(
            title: "Invalid member name",
            detail: "Use postedAt, not createdAt.",
            parameter: "fields[topics]",
          ).deep_stringify_keys,
        )
      end
    end
  end

  context "when the client is pinned between the first version and the change" do
    let(:version) { (first_version.date + 1.day).to_s }

    it "sends the first version" do
      expect(response.headers["Api-Version"]).to eq(first_version.to_s)
    end

    it "sends the attributes under the names of the first version" do
      expect(attributes.keys).to contain_exactly("title", "postedAt")
    end
  end

  context "when the client is pinned at the change" do
    let(:version) { change_version.to_s }

    it "sends the version of the change" do
      expect(response.headers["Api-Version"]).to eq(change_version.to_s)
    end

    it "sends the attributes under the names of that version" do
      expect(attributes.keys).to contain_exactly("title", "createdAt")
    end

    context "when the request selects the field" do
      let(:query) { { "fields" => { "topics" => "createdAt" } } }

      it "sends that field only" do
        expect(attributes.keys).to contain_exactly("createdAt")
      end
    end
  end
end
