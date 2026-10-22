# frozen_string_literal: true

module JsonApiKitSpec
  class InputScopeTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    scope { |guardian| Topic.where(user_id: guardian.user&.id) }
    attribute :title
    sort :created_at
    default_sort created_at: :asc

    collection :workable do
      # Leaving `closed_too` out means "open topics only", not "every topic".
      scope_filter :closed_too, default: false
      filter :title

      # A title search reaches closed topics too, so the scope reads the ordinary filter as well.
      input_scope do |topics, _guardian, closed_too:, title: nil|
        closed_too = ActiveModel::Type::Boolean.new.cast(closed_too)
        closed_too || title ? topics : topics.where(closed: false)
      end
    end
  end

  class WorkableTopicsController < JsonApiKit::BaseController
    resource InputScopeTopicResource.collection(:workable)
  end
end

RSpec.describe "JSON:API input scopes", type: :request do
  fab!(:author, :user)
  fab!(:open_topic) do
    Fabricate(:topic, user: author, closed: false, created_at: Time.utc(2026, 8, 1))
  end
  fab!(:closed_topic) do
    Fabricate(:topic, user: author, closed: true, created_at: Time.utc(2026, 8, 2))
  end
  fab!(:other_topic) { Fabricate(:topic, closed: false) }

  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }

  before do
    sign_in(author)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/workable-topics" => "json_api_kit_spec/workable_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  def fetch(parameters = {})
    get "/api/workable-topics",
        headers: {
          "HTTP_API_VERSION" => JsonApiKit::Timeline.current.to_s,
        },
        params: parameters
  end

  it "runs the input scope with the default when the request leaves the input out" do
    fetch

    expect(ids).to eq([open_topic.id.to_s])
  end

  it "runs the input scope with the value the request sends" do
    fetch(filter: { closedToo: "true" })

    expect(ids).to eq([open_topic.id.to_s, closed_topic.id.to_s])
  end

  it "hands the input scope an ordinary filter it reads, which still narrows" do
    fetch(filter: { title: closed_topic.title })

    expect(ids).to eq([closed_topic.id.to_s])
  end
end
