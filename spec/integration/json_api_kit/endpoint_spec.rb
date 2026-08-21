# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class TopicsController < JsonApiKit::BaseController
    def index
      render_document(
        JsonApiKit::Document::Collection.for(
          request.query_parameters,
          resource: TopicResource,
          guardian:,
          urls:,
        ),
      )
    end

    def show
      render_document(
        JsonApiKit::Document::Individual.for(
          params[:id],
          request.query_parameters,
          resource: TopicResource,
          guardian:,
          urls:,
        ),
      )
    end
  end
end

module JsonApiKitSpec
  class FailingController < JsonApiKit::BaseController
    def index = raise "the reason nobody planned for"

    def show = raise Discourse::NotFound

    def forbidden = raise Discourse::InvalidAccess
  end
end

RSpec.describe "a JSON:API endpoint", type: :request do
  include_context "with a listing of topics"

  let(:base) { "http://test.localhost/api" }
  let(:current) { "#{base}/topics" }
  let(:media_type) { "application/vnd.api+json" }
  let(:profile) { "https://jsonapi.org/profiles/ethanresnick/cursor-pagination" }
  let(:path) { "/api/topics" }
  let(:headers) { {} }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:error) { parsed_body["errors"].sole }

  before do
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/topics" => "json_api_kit_spec/topics#index"
      get "/api/topics/:id" => "json_api_kit_spec/topics#show"
      get "/api/failing" => "json_api_kit_spec/failing#index"
      get "/api/missing" => "json_api_kit_spec/failing#show"
      get "/api/forbidden" => "json_api_kit_spec/failing#forbidden"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get path, headers:, params: query
  end

  after { Rails.application.reload_routes! }

  describe "the response" do
    it "sends the JSON:API media type" do
      expect(response.media_type).to eq(media_type)
    end

    it "varies on the accept header" do
      expect(response.headers["Vary"]).to include("Accept")
    end

    context "when the path ends with a format" do
      let(:path) { "/api/topics.json" }

      it "sends the JSON:API media type" do
        expect(response.media_type).to eq(media_type)
      end

      it "varies on the accept header" do
        expect(response.headers["Vary"]).to include("Accept")
      end
    end

    context "when the content type carries another parameter" do
      let(:headers) { { "CONTENT_TYPE" => "#{media_type};charset=utf-8" } }

      it "varies on the accept header" do
        expect(response.headers["Vary"]).to include("Accept")
      end
    end
  end

  describe "fetching a collection" do
    let(:query) { { "page" => { "size" => "2" }, "fields" => { "topics" => "title" } } }
    let(:fields) { %w[title] }

    it "sends the first page of the collection" do
      expect(parsed_body).to eq(
        {
          data: [topic_object(newest, fields:), topic_object(middle, fields:)],
          included: [],
          links: links_of(next: page_url(after: cursor_of_record(middle), size: 2)),
        }.deep_stringify_keys,
      )
    end

    context "when the request sorts by title" do
      let(:query) { { "sort" => "title", "fields" => { "topics" => "title" } } }
      let(:sort) { { "title" => :asc } }

      it "sends the rows in that order" do
        expect(parsed_body).to eq(
          {
            data: [
              topic_object(oldest, fields:),
              topic_object(newest, fields:),
              topic_object(middle, fields:),
            ],
            included: [],
            links: links_of,
          }.deep_stringify_keys,
        )
      end
    end
  end

  describe "fetching one record" do
    let(:path) { "/api/topics/#{middle.id}" }
    let(:current) { "#{base}/topics/#{middle.id}" }
    let(:query) { { "fields" => { "topics" => "title" } } }

    it "sends the record" do
      expect(parsed_body).to eq(
        {
          data: topic_object(middle, fields: %w[title]),
          included: [],
          links: {
            self: self_link,
          },
        }.deep_stringify_keys,
      )
    end

    context "when no record has that id" do
      let(:path) { "/api/topics/0" }

      it { expect(response).to have_http_status(:not_found) }

      it "sends the reason" do
        expect(error).to eq(not_found.deep_stringify_keys)
      end
    end
  end

  describe "an unexpected error" do
    let(:path) { "/api/failing" }

    it { expect(response).to have_http_status(:internal_server_error) }

    it "sends the JSON:API media type" do
      expect(response.media_type).to eq(media_type)
    end

    it "sends the reason" do
      expect(error).to eq(
        "status" => "500",
        "title" => "Internal server error",
        "detail" => "The server could not answer this request.",
      )
    end

    context "when Discourse answers the error itself" do
      let(:path) { "/api/missing" }

      it { expect(response).to have_http_status(:not_found) }

      it "sends JSON" do
        expect(response.media_type).to eq("application/json")
      end
    end
  end

  describe "a request Discourse refuses" do
    let(:path) { "/api/forbidden" }

    it { expect(response).to have_http_status(:forbidden) }

    it "sends the JSON:API media type" do
      expect(response.media_type).to eq(media_type)
    end

    it "sends the reason" do
      expect(error).to eq(
        "status" => "403",
        "title" => "Forbidden",
        "detail" => "You are not allowed to make this request.",
      )
    end
  end

  describe "the content type of a request" do
    context "when there is none" do
      it { expect(response).to have_http_status(:ok) }
    end

    context "when it carries a profile parameter" do
      let(:headers) { { "CONTENT_TYPE" => %(#{media_type};profile="#{profile}") } }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when it carries another parameter" do
      let(:headers) { { "CONTENT_TYPE" => "#{media_type};charset=utf-8" } }

      it { expect(response).to have_http_status(:unsupported_media_type) }

      it "sends the reason" do
        expect(error).to eq(
          "status" => "415",
          "title" => "Unsupported media type",
          "detail" => "Content-Type accepts the ext and profile parameters only.",
        )
      end
    end

    context "when it applies an extension" do
      let(:headers) { { "CONTENT_TYPE" => %(#{media_type};ext="https://example.com/x") } }

      it { expect(response).to have_http_status(:unsupported_media_type) }

      it "sends the reason" do
        expect(error).to eq(
          "status" => "415",
          "title" => "Unsupported media type",
          "detail" => "This API applies no extension.",
        )
      end
    end
  end

  describe "the accept header of a request" do
    context "when it allows the JSON:API media type" do
      let(:headers) { { "HTTP_ACCEPT" => media_type } }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when it allows another media type" do
      let(:headers) { { "HTTP_ACCEPT" => "text/csv" } }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when one instance carries no other parameter" do
      let(:headers) { { "HTTP_ACCEPT" => "#{media_type};charset=utf-8, #{media_type}" } }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when an instance carries a weight" do
      let(:headers) { { "HTTP_ACCEPT" => "#{media_type};q=0.9" } }

      it { expect(response).to have_http_status(:ok) }
    end

    context "when every instance carries another parameter" do
      let(:headers) do
        { "HTTP_ACCEPT" => "#{media_type};charset=utf-8, #{media_type};version=1;q=0.9" }
      end

      it { expect(response).to have_http_status(:not_acceptable) }

      it "sends the reason" do
        expect(error).to eq(
          "status" => "406",
          "title" => "Not acceptable",
          "detail" => "Accept must allow #{media_type} with the ext and profile parameters only.",
        )
      end
    end
  end
end
