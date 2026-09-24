# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class RequestBodyTopicsController < JsonApiKit::BaseController
    resource :topics

    def create
      render json: request_body.to_h, content_type: JsonApiKit::MediaType::JSON_API
    end
  end

  class RenameRequestBodyTopics < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Discussion threads become topics."

    renamed_type from: :discussion_threads, to: :topics

    resource :topics do
      renamed_attribute from: :heading, to: :title
    end
  end
end

RSpec.describe JsonApiKitSpec::RequestBodyTopicsController, type: :request do
  describe "#create" do
    let(:path) { "/api/request-body-topics" }
    let(:document) { { "data" => primary } }
    let(:primary) { { "type" => "topics", "attributes" => attributes } }
    let(:attributes) { { "title" => "A new topic" } }
    let(:body) { document.to_json }
    let(:version) { "2026-09-01" }
    let(:version_changes) do
      JsonApiKit::VersionChanges.new([JsonApiKitSpec::RenameRequestBodyTopics.new(__FILE__)])
    end
    let(:parsed_body) { JSON.parse(response.body) }
    let(:status) { 400 }

    before do
      freeze_time(Date.new(2026, 9, 2))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
      Rails.application.routes.disable_clear_and_finalize = true
      Rails.application.routes.draw do
        post "/api/request-body-topics" => "json_api_kit_spec/request_body_topics#create"
      end
      Rails.application.routes.disable_clear_and_finalize = false
      post path,
           params: body,
           headers: {
             "HTTP_API_VERSION" => version,
             "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API,
           }
    end

    after { Rails.application.reload_routes! }

    shared_examples "a refused request body" do
      it "returns the refusal at the submitted location", :aggregate_failures do
        expect(response).to have_http_status(status)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => status.to_s, "source" => { "pointer" => pointer }),
        )
      end
    end

    it "supplies the document to the action", :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(parsed_body).to eq(document)
    end

    context "when attributes are omitted" do
      let(:primary) { super().except("attributes") }

      it "preserves their absence" do
        expect(parsed_body).to eq(document)
      end
    end

    context "when attributes are empty" do
      let(:attributes) { {} }

      it "supplies the empty object to the action" do
        expect(parsed_body).to eq(document)
      end
    end

    context "when an attribute is null" do
      let(:attributes) { super().merge("title" => nil) }

      it "preserves the explicit null" do
        expect(parsed_body).to eq(document)
      end
    end

    context "when attributes are undeclared" do
      let(:attributes) do
        {
          "unknownField" => "something",
          "enabled" => false,
          "count" => 0,
          "settings" => {
            "labels" => ["one", nil, "two"],
          },
        }
      end

      it "supplies their names and values to the action" do
        expect(parsed_body).to eq(document)
      end
    end

    context "when the query supplies conflicting data" do
      let(:path) { "#{super()}?data[type]=users" }

      it "refuses the unsupported query parameter", :aggregate_failures do
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "400", "source" => { "parameter" => "data[type]" }),
        )
      end
    end

    context "when the document contains an additional member" do
      let(:document) { super().merge("extra" => true) }

      it "accepts the resource object", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(parsed_body.fetch("data")).to eq(primary)
      end
    end

    context "when the document contains data and errors" do
      let(:document) { super().merge("errors" => []) }
      let(:pointer) { "/errors" }

      it_behaves_like "a refused request body"
    end

    context "when the document is an array" do
      let(:document) { [super()] }
      let(:pointer) { "" }

      it_behaves_like "a refused request body"
    end

    context "when the document is null" do
      let(:document) { nil }
      let(:pointer) { "" }

      it_behaves_like "a refused request body"
    end

    context "when data is omitted" do
      let(:document) { {} }
      let(:pointer) { "" }

      it_behaves_like "a refused request body"
    end

    context "when only the query supplies data" do
      let(:path) { "#{super()}?data[type]=topics" }
      let(:document) { {} }

      it "refuses the unsupported query parameter", :aggregate_failures do
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to include(
          a_hash_including("status" => "400", "source" => { "parameter" => "data[type]" }),
        )
      end
    end

    context "when data is an array" do
      let(:primary) { [super()] }
      let(:pointer) { "/data" }

      it_behaves_like "a refused request body"
    end

    context "when data is null" do
      let(:primary) { nil }
      let(:pointer) { "/data" }

      it_behaves_like "a refused request body"
    end

    context "when the type is omitted" do
      let(:primary) { super().except("type") }
      let(:pointer) { "/data" }

      it_behaves_like "a refused request body"
    end

    context "when the type is a number" do
      let(:primary) { super().merge("type" => 123) }
      let(:pointer) { "/data/type" }

      it_behaves_like "a refused request body"
    end

    context "when the type is null" do
      let(:primary) { super().merge("type" => nil) }
      let(:pointer) { "/data/type" }

      it_behaves_like "a refused request body"
    end

    context "when the type belongs to another resource" do
      let(:primary) { super().merge("type" => "users") }
      let(:status) { 409 }
      let(:pointer) { "/data/type" }

      it_behaves_like "a refused request body"
    end

    context "when attributes are null" do
      let(:attributes) { nil }
      let(:pointer) { "/data/attributes" }

      it_behaves_like "a refused request body"
    end

    context "when attributes are an array" do
      let(:attributes) { [] }
      let(:pointer) { "/data/attributes" }

      it_behaves_like "a refused request body"
    end

    context "when the client supplies an id" do
      let(:primary) { super().merge("id" => "550e8400-e29b-41d4-a716-446655440000") }
      let(:status) { 403 }
      let(:pointer) { "/data/id" }

      it_behaves_like "a refused request body"
    end

    context "when the client uses a historical version" do
      let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
      let(:primary) { super().merge("type" => "discussionThreads") }
      let(:attributes) { { "heading" => "A new topic" } }

      it "accepts the historical type", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(parsed_body).to eq(document)
      end

      context "when the client supplies the current type" do
        let(:primary) { super().merge("type" => "topics") }
        let(:status) { 409 }
        let(:pointer) { "/data/type" }

        it_behaves_like "a refused request body"
      end
    end

    context "when the client supplies a historical type in the current version" do
      let(:primary) { super().merge("type" => "discussionThreads") }
      let(:status) { 409 }
      let(:pointer) { "/data/type" }

      it_behaves_like "a refused request body"
    end

    context "when the body contains malformed JSON" do
      let(:body) { '{"data":' }

      it "returns a JSON:API error", :aggregate_failures do
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(a_hash_including("status" => "400"))
      end
    end
  end
end
