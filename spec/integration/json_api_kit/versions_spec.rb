# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class VersionedTopicsController < JsonApiKit::BaseController
    resource :topics
  end
end

RSpec.describe "JSON:API versioning", type: :request do
  include_context "with a listing of topics"

  let(:first_version) { JsonApiKit::Timeline.first.to_s }
  let(:first_date) { Date.parse(first_version) }
  let(:version) { first_version }
  let(:headers) { { "HTTP_API_VERSION" => version } }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:error) { parsed_body["errors"].sole }

  before do
    freeze_time(first_date + 1.year)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/versioned-topics" => "json_api_kit_spec/versioned_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/versioned-topics", headers:
  end

  after { Rails.application.reload_routes! }

  it { expect(response).to have_http_status(:ok) }

  it "sends the version it resolved" do
    expect(response.headers["Api-Version"]).to eq(first_version)
  end

  context "when the version is later than the first one" do
    let(:version) { (first_date + 1.day).to_s }

    it { expect(response).to have_http_status(:ok) }

    it "sends the newest version at or before it" do
      expect(response.headers["Api-Version"]).to eq(first_version)
    end
  end

  context "when the version is earlier than the first one" do
    let(:version) { (first_date - 1.day).to_s }

    it { expect(response).to have_http_status(:bad_request) }

    it "sends the reason" do
      expect(error).to eq(
        refusal(
          title: "No such version",
          detail: "The first version is #{first_version}.",
          header: "Api-Version",
        ).deep_stringify_keys,
      )
    end
  end

  context "when the version is in the future" do
    let(:version) { (Time.zone.today + 1.day).to_s }

    it { expect(response).to have_http_status(:bad_request) }

    it "sends the reason" do
      expect(error).to eq(
        refusal(
          title: "Api-Version is in the future",
          detail:
            "Api-Version must not be later than today in UTC. The current version is #{first_version}.",
          header: "Api-Version",
        ).deep_stringify_keys,
      )
    end
  end

  context "when the version is not a date" do
    let(:version) { "yesterday" }

    it { expect(response).to have_http_status(:bad_request) }

    it "sends the reason" do
      expect(error).to eq(
        refusal(
          title: "Api-Version is not a date",
          detail: "Api-Version must be written as YYYY-MM-DD.",
          header: "Api-Version",
        ).deep_stringify_keys,
      )
    end
  end

  context "when the version header is missing" do
    let(:headers) { {} }

    it { expect(response).to have_http_status(:bad_request) }

    it "sends the reason" do
      expect(error).to eq(
        refusal(
          title: "Api-Version is required",
          detail: "Send Api-Version: #{first_version}.",
          header: "Api-Version",
        ).deep_stringify_keys,
      )
    end

    it "sends no version" do
      expect(response.headers).not_to have_key("Api-Version")
    end
  end
end
