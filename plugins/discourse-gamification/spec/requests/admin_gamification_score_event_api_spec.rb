# frozen_string_literal: true

RSpec.describe DiscourseGamification::AdminGamificationScoreEventController do
  fab!(:admin)
  fab!(:user)
  let(:api_key) { Fabricate(:api_key, user: admin) }
  let!(:api_key_scope) do
    Fabricate(
      :api_key_scope,
      api_key_id: api_key.id,
      resource: "gamification",
      action: "create_score_events",
    )
  end
  fab!(:score_event) do
    DiscourseGamification::GamificationScoreEvent.create!(user: user, date: Date.current, points: 5)
  end

  let(:headers) { { "Api-Key" => api_key.key } }
  let(:create_params) do
    { user_id: user.id, date: Date.current, points: 10, description: "Contest prize" }
  end

  before { SiteSetting.discourse_gamification_enabled = true }

  describe "#show" do
    it "reads score events with the read scope" do
      api_key_scope.update!(action: "read_score_events")

      get "/admin/plugins/gamification/score_events.json",
          params: {
            user_id: user.id,
          },
          headers: headers

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |event| event["id"] }).to eq([score_event.id])
    end

    it "rejects a create-only key" do
      get "/admin/plugins/gamification/score_events.json", headers: headers

      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    it "awards points with the create scope" do
      expect {
        post "/admin/plugins/gamification/score_events.json",
             params: create_params,
             headers: headers
      }.to change { DiscourseGamification::GamificationScoreEvent.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "user_id" => user.id,
        "points" => 10,
        "description" => "Contest prize",
      )
    end

    %w[read_score_events update_score_events].each do |action|
      it "rejects a key with only the #{action} scope" do
        api_key_scope.update!(action: action)

        expect {
          post "/admin/plugins/gamification/score_events.json",
               params: create_params,
               headers: headers
        }.not_to change { DiscourseGamification::GamificationScoreEvent.count }

        expect(response.status).to eq(404)
      end
    end

    %i[user moderator].each do |role|
      it "rejects a #{role}'s key even with the create scope" do
        api_key.update!(user: Fabricate(role))

        expect {
          post "/admin/plugins/gamification/score_events.json",
               params: create_params,
               headers: headers
        }.not_to change { DiscourseGamification::GamificationScoreEvent.count }

        expect(response.status).to eq(role == :moderator ? 403 : 404)
      end
    end

    it "rejects a key with an unrelated scope" do
      api_key_scope.update!(resource: "topics", action: "write")

      expect {
        post "/admin/plugins/gamification/score_events.json",
             params: create_params,
             headers: headers
      }.not_to change { DiscourseGamification::GamificationScoreEvent.count }

      expect(response.status).to eq(404)
    end

    it "rejects requests when the plugin is disabled" do
      SiteSetting.discourse_gamification_enabled = false

      expect {
        post "/admin/plugins/gamification/score_events.json",
             params: create_params,
             headers: headers
      }.not_to change { DiscourseGamification::GamificationScoreEvent.count }

      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    it "updates score events with the update scope" do
      api_key_scope.update!(action: "update_score_events")

      put "/admin/plugins/gamification/score_events.json",
          params: {
            id: score_event.id,
            points: 20,
          },
          headers: headers

      expect(response.status).to eq(200)
      expect(score_event.reload.points).to eq(20)
    end

    it "rejects a create-only key" do
      put "/admin/plugins/gamification/score_events.json",
          params: {
            id: score_event.id,
            points: 20,
          },
          headers: headers

      expect(response.status).to eq(404)
      expect(score_event.reload.points).to eq(5)
    end
  end

  it "rejects unrelated admin operations with a create-only key" do
    put "/admin/plugins/gamification/recalculate-scores.json", headers: headers

    expect(response.status).to eq(404)

    get "/admin/users.json", headers: headers

    expect(response.status).to eq(404)
  end
end
