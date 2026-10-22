# frozen_string_literal: true

module JsonApiKitSpec
  class InputScopeHistoryTopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    scope { |_guardian| Topic.where(visible: true) }
    attribute :title
    sort :created_at
    default_sort created_at: :asc

    collection :workable do
      scope_filter :closed_too, default: false
      # Reuses the name of the input that 2026-09-10 removed, with a different default.
      scope_filter :mine, default: false

      input_scope do |topics, guardian, closed_too:, mine:|
        topics = topics.where(closed: false) unless ActiveModel::Type::Boolean.new.cast(closed_too)
        ActiveModel::Type::Boolean.new.cast(mine) ? topics.where(user_id: guardian.user.id) : topics
      end
    end
  end

  class InputScopeHistoryTopicsController < JsonApiKit::BaseController
    resource InputScopeHistoryTopicResource.collection(:workable)
  end
end

RSpec.describe JsonApiKitSpec::InputScopeHistoryTopicsController, type: :request do
  fab!(:author, :user)
  fab!(:own_topic) do
    Fabricate(:topic, user: author, closed: false, created_at: Time.utc(2026, 8, 1))
  end
  fab!(:own_closed_topic) do
    Fabricate(:topic, user: author, closed: true, created_at: Time.utc(2026, 8, 2))
  end
  fab!(:other_topic) { Fabricate(:topic, closed: false, created_at: Time.utc(2026, 8, 3)) }
  fab!(:invisible_topic) do
    Fabricate(:topic, user: author, closed: false, visible: false, created_at: Time.utc(2026, 8, 4))
  end

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:parameters) { {} }
  let(:body) { JSON.parse(response.body) }
  let(:ids) { body.fetch("data").map { it.fetch("id") } }
  let(:error) { body.fetch("errors").sole }

  # Before 2026-09-10 the workable topics were the author's own unless `mine` was false, the
  # input defaulted to true, and closed topics never counted.
  let(:removal_class) do
    Class.new(JsonApiKit::VersionChange) do
      version "2026-09-10"
      description "Workable topics take any author unless the request asks for its own."

      resource :topics do
        collection :workable do
          removed_scope_filter :mine, default: true
          changed_input_scope do |topics, guardian, mine:|
            topics = topics.where(closed: false)
            if ActiveModel::Type::Boolean.new.cast(mine)
              topics.where(user_id: guardian.user.id)
            else
              Topic.all
            end
          end
        end
      end
    end
  end
  let(:changes) { [removal_class.new(__FILE__)] }

  before do
    freeze_time(Date.new(2026, 9, 18))
    sign_in(author)
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(
      JsonApiKit::VersionChanges.new(changes),
    )
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/workable-history-topics" => "json_api_kit_spec/input_scope_history_topics#index"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/workable-history-topics",
        headers: {
          "HTTP_API_VERSION" => version,
        },
        params: parameters
  end

  after { Rails.application.reload_routes! }

  context "with a pin from before the change" do
    it "runs the retained input scope with the retained default" do
      expect(ids).to eq([own_topic.id.to_s])
    end

    context "when the request sends the removed input" do
      let(:parameters) { { filter: { mine: "false" } } }

      it "hands it to the retained input scope, which stays within today's visible rows" do
        expect(ids).to eq([own_topic.id.to_s, own_closed_topic.id.to_s, other_topic.id.to_s])
      end
    end

    context "when the request sends an input only today's input scope reads" do
      let(:parameters) { { filter: { closedToo: "true" } } }

      it "accepts it without the retained input scope reading it" do
        expect(ids).to eq([own_topic.id.to_s])
      end
    end
  end

  context "with the pin that includes the change" do
    let(:version) { "2026-09-10" }

    it "runs today's input scope with today's defaults" do
      expect(ids).to eq([own_topic.id.to_s, other_topic.id.to_s])
    end

    context "when the request sends the reused input" do
      let(:parameters) { { filter: { mine: "true", closedToo: "true" } } }

      it "hands today's input scope its value" do
        expect(ids).to eq([own_topic.id.to_s, own_closed_topic.id.to_s])
      end
    end
  end

  context "when a later change replaces the input scope again" do
    let(:changes) do
      [
        removal_class.new(__FILE__),
        Class
          .new(JsonApiKit::VersionChange) do
            version "2026-09-15"
            description "Workable topics briefly listed closed ones only."

            resource :topics do
              collection :workable do
                changed_input_scope { |topics, _guardian| topics.where(closed: true) }
              end
            end
          end
          .new(__FILE__),
      ]
    end

    it "runs the oldest retained input scope for the oldest pin" do
      expect(ids).to eq([own_topic.id.to_s])
    end

    context "when the pin is between the changes" do
      let(:version) { "2026-09-10" }

      it "runs the input scope that the later change replaced" do
        expect(ids).to eq([own_closed_topic.id.to_s])
      end
    end
  end

  context "when a later change removes the same input again" do
    let(:parameters) { { filter: { mine: "true" } } }
    let(:changes) do
      [
        removal_class.new(__FILE__),
        Class
          .new(JsonApiKit::VersionChange) do
            version "2026-09-15"
            description "Workable topics briefly took mine, defaulting to every author."

            resource :topics do
              collection :workable do
                removed_scope_filter :mine, default: false
                changed_input_scope { |topics, _guardian, mine:| topics }
              end
            end
          end
          .new(__FILE__),
      ]
    end

    it "hands the oldest pin's value to the input scope the oldest removal retained" do
      expect(ids).to eq([own_topic.id.to_s])
    end
  end
end
