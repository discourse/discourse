# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class CasedTopicsController < JsonApiKit::BaseController
    resource :topics
  end
end

RSpec.describe "JSON:API member names", type: :request do
  include_context "with a listing of topics"

  let(:path) { "/api/topics" }
  let(:query) { {} }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:error) { parsed_body["errors"].sole }
  let(:attributes) { parsed_body["data"].first["attributes"] }
  let(:ids) { parsed_body["data"].map { it["id"] } }

  before do
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw { get "/api/topics" => "json_api_kit_spec/cased_topics#index" }
    Rails.application.routes.disable_clear_and_finalize = false
    get path, headers: { "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s }, params: query
  end

  after { Rails.application.reload_routes! }

  it "sends attribute names in camel case" do
    expect(attributes.keys).to contain_exactly("title", "createdAt")
  end

  context "when the request selects fields" do
    let(:query) { { "fields" => { "topics" => "createdAt" } } }

    it "sends that field only" do
      expect(attributes.keys).to contain_exactly("createdAt")
    end
  end

  context "when the request sorts" do
    let(:query) { { "sort" => "createdAt" } }

    it "orders the rows by that attribute" do
      expect(ids).to eq([oldest.id.to_s, middle.id.to_s, newest.id.to_s])
    end
  end

  context "when the request uses snake case" do
    let(:query) { { "sort" => "created_at" } }

    it { expect(response).to have_http_status(:bad_request) }

    it "sends the reason" do
      expect(error).to eq(
        refusal(
          title: "Invalid member name",
          detail: "Use createdAt, not created_at.",
          parameter: "sort",
        ).deep_stringify_keys,
      )
    end
  end

  context "when the request anchors a window on an attribute" do
    let(:query) do
      {
        "sort" => "createdAt",
        "page" => {
          "anchor" => {
            "createdAt" => middle.created_at.iso8601(6),
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

  context "when the request anchors on a computed position" do
    let(:query) { { "page" => { "anchor" => "withoutReplies", "afterSize" => "1" } } }

    it "sends the rows from that position" do
      expect(ids).to eq([newest.id.to_s, middle.id.to_s])
    end
  end

  context "when the request asks for the cursor of each row" do
    let(:query) { { "page" => { "itemCursors" => "true" } } }

    it "sends a cursor on every row" do
      expect(parsed_body["data"].map { it.dig("meta", "page", "cursor") }).to all(be_present)
    end
  end

  context "when the request includes a relationship" do
    let(:query) { { "include" => "orderedPosts" } }
    let(:relationship) { parsed_body["data"].first["relationships"]["orderedPosts"] }

    it "sends the relationship under its camel case name" do
      expect(relationship).to be_present
    end

    it "sends its links under that name" do
      expect(relationship["links"]["related"]).to end_with("/orderedPosts")
    end
  end

  context "when a page parameter is invalid" do
    let(:query) do
      {
        "page" => {
          "anchor" => {
            "createdAt" => middle.created_at.iso8601(6),
          },
          "beforeSize" => "-1",
        },
      }
    end

    let(:parameters) { parsed_body["errors"].map { it.dig("source", "parameter") } }

    it "sends the parameter in camel case" do
      expect(parameters).to include("page[beforeSize]")
    end
  end
end
