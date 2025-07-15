# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseGamification::AdminGamificationScoreEventController do
  let(:current_user) { Fabricate(:admin) }
  let(:another_user) { Fabricate(:user) }
  let(:score_events) { [] }

  before do
    SiteSetting.discourse_gamification_enabled = true

    score_events << DiscourseGamification::GamificationScoreEvent.create!(
      user_id: current_user.id,
      date: Date.today,
      points: 7,
    )

    score_events << DiscourseGamification::GamificationScoreEvent.create!(
      user_id: current_user.id,
      date: Date.yesterday,
      points: 17,
    )

    score_events << DiscourseGamification::GamificationScoreEvent.create!(
      user_id: another_user.id,
      date: Date.yesterday,
      points: 27,
    )

    DiscourseGamification::GamificationScore.calculate_scores(since_date: 10.days.ago.midnight)
    sign_in(current_user)
  end

  describe "#index" do
    it "returns users and their calculated scores" do
      get "/admin/plugins/gamification/score_events.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].length).to eq(score_events.size)
      expect(response.parsed_body["events"][0]["points"]).to eq(score_events[0].points)
    end

    it "returns users and their calculated scores for a specific date" do
      get "/admin/plugins/gamification/score_events.json?date=#{Date.today}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].length).to eq(1)
      expect(response.parsed_body["events"][0]["points"]).to eq(7)
    end

    it "returns users and their calculated scores for a specific user" do
      get "/admin/plugins/gamification/score_events.json?user_id=#{current_user.id}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].length).to eq(2)
      expect(response.parsed_body["events"].map { _1["points"] }.sum).to eq(24)
    end

    it "returns users and their calculated scores for a specific user and date" do
      get "/admin/plugins/gamification/score_events.json?user_id=#{another_user.id}&date=#{Date.today}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].length).to eq(0)
    end

    it "returns users and their calculated scores for a event id" do
      get "/admin/plugins/gamification/score_events.json?id=#{score_events.last.id}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].length).to eq(1)
      expect(response.parsed_body["events"][0]["id"]).to eq(score_events.last.id)
    end

    it "affects user scores when a score event is created" do
      post "/admin/plugins/gamification/score_events.json",
           params: {
             points: 10,
             user_id: another_user.id,
             date: Date.today,
           }
      expect(response.status).to eq(200)

      DiscourseGamification::GamificationScore.calculate_scores(since_date: 10.days.ago.midnight)
      user_score =
        DiscourseGamification::GamificationScore.where(user_id: another_user.id).sum(:score)
      expect(user_score).to eq(37)
    end

    it "affects user scores when a score event is deleted" do
      put "/admin/plugins/gamification/score_events.json",
          params: {
            id: score_events.last.id,
            points: 13,
            user_id: another_user.id,
            date: Date.yesterday,
          }
      expect(response.status).to eq(200)

      DiscourseGamification::GamificationScore.calculate_scores(since_date: 10.days.ago.midnight)

      user_score =
        DiscourseGamification::GamificationScore.where(user_id: another_user.id).sum(:score)
      expect(user_score).to eq(13)
    end
  end
end
