# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseGamification::GamificationLeaderboardController do
  let(:group) { Fabricate(:group) }
  let(:current_user) { Fabricate(:user, group_ids: [group.id]) }
  let(:user_2) { Fabricate(:user) }
  let(:staged_user) { Fabricate(:user, staged: true) }
  let(:anon_user) { Fabricate(:user, email: "john@anonymized.invalid") }
  let!(:create_score) { UserVisit.create(user_id: current_user.id, visited_at: 2.days.ago) }
  let!(:create_score_for_user2) { UserVisit.create(user_id: user_2.id, visited_at: 2.days.ago) }
  let!(:create_score_for_staged_user) do
    UserVisit.create(user_id: staged_user.id, visited_at: 2.days.ago)
  end
  let!(:create_score_for_anon_user) do
    UserVisit.create(user_id: anon_user.id, visited_at: 2.days.ago)
  end
  let!(:create_topic) { Fabricate(:topic, user: current_user) }
  let!(:leaderboard) do
    Fabricate(:gamification_leaderboard, name: "test", created_by_id: current_user.id)
  end
  let!(:leaderboard_2) do
    Fabricate(
      :gamification_leaderboard,
      name: "test_2",
      created_by_id: current_user.id,
      from_date: 3.days.ago,
      to_date: 1.day.ago,
    )
  end
  let!(:leaderboard_with_group) do
    Fabricate(
      :gamification_leaderboard,
      name: "test_3",
      created_by_id: current_user.id,
      included_groups_ids: [group.id],
      visible_to_groups_ids: [group.id],
    )
  end

  let!(:leaderboard_with_default_period_set_to_daily) do
    Fabricate(
      :gamification_leaderboard,
      name: "test_4",
      created_by_id: current_user.id,
      default_period: 5,
    )
  end

  before do
    SiteSetting.discourse_gamification_enabled = true
    DiscourseGamification::GamificationScore.calculate_scores(since_date: 10.days.ago)
    sign_in(current_user)
  end

  describe "#respond" do
    it "returns users and their calculated scores" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create

      get "/leaderboard/#{leaderboard.id}.json"
      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data["users"][0]["username"]).to eq(current_user.username)
      expect(data["users"][0]["avatar_template"]).to eq(current_user.avatar_template)
      expect(data["users"][0]["total_score"]).to eq(current_user.gamification_score)
    end

    it "returns an in progress message when leaderboard positions are not ready" do
      expect do get "/leaderboard/#{leaderboard.id}.json" end.to change {
        Jobs::GenerateLeaderboardPositions.jobs.size
      }.by(1)

      expect(response.status).to eq(202)
      expect(response.parsed_body["reason"]).to eq(I18n.t("errors.leaderboard_positions_not_ready"))
    end

    it "only returns users and scores for specified date range" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard_2).create
      get "/leaderboard/#{leaderboard_2.id}.json"

      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data["users"][0]["username"]).to eq(current_user.username)
      expect(data["users"][0]["avatar_template"]).to eq(current_user.avatar_template)
      expect(data["users"][0]["total_score"]).to eq(1)
    end

    it "respects the user_limit parameter" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create

      get "/leaderboard/#{leaderboard.id}.json?user_limit=1"
      expect(response.status).to eq(200)

      data = response.parsed_body
      expect(data["users"].count).to eq(1)
    end

    it "only returns users that are a part of a group within included_groups_ids" do
      # multiple scores present
      expect(DiscourseGamification::GamificationScore.all.map(&:user_id)).to include(
        current_user.id,
        user_2.id,
      )

      DiscourseGamification::LeaderboardCachedView.new(leaderboard_with_group).create

      get "/leaderboard/#{leaderboard_with_group.id}.json"
      expect(response.status).to eq(200)

      data = response.parsed_body
      # scoped to group
      expect(data["users"].map { |u| u["id"] }).to eq([current_user.id])
    end

    it "excludes staged and anon users" do
      # prove score for staged/anon user exists
      expect(DiscourseGamification::GamificationScore.all.map(&:user_id)).to include(
        staged_user.id,
        anon_user.id,
      )
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create

      get "/leaderboard/#{leaderboard.id}.json"
      data = response.parsed_body
      expect(data["users"].map { |u| u["id"] }).to_not include(staged_user.id, anon_user.id)
    end

    it "does not error if visible_to_groups_ids or included_groups_ids are empty" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
      get "/leaderboard/#{leaderboard.id}.json"
      expect(response.status).to eq(200)
    end

    it "errors if visible_to_groups_ids are present and user in not a part of a included group" do
      current_user.groups = []
      get "/leaderboard/#{leaderboard_with_group.id}.json"
      expect(response.status).to eq(404)
    end

    it "displays leaderboard to users included in group within visible_to_groups_ids" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard_with_group).create

      get "/leaderboard/#{leaderboard_with_group.id}.json"
      expect(response.status).to eq(200)
    end

    it "allows admins to see all leaderboards" do
      current_user = Fabricate(:admin)
      DiscourseGamification::LeaderboardCachedView.new(leaderboard_with_group).create

      sign_in(current_user)
      get "/leaderboard/#{leaderboard_with_group.id}.json"
      expect(response.status).to eq(200)
    end

    it "displays leaderboard for the default leaderboard period" do
      DiscourseGamification::LeaderboardCachedView.new(leaderboard).create
      DiscourseGamification::LeaderboardCachedView.new(
        leaderboard_with_default_period_set_to_daily,
      ).create

      get "/leaderboard/#{leaderboard.id}.json"
      regular_user_score = response.parsed_body["users"][0]["total_score"]

      get "/leaderboard/#{leaderboard.id}.json?period=daily"
      daily_user_score = response.parsed_body["users"][0]["total_score"]

      get "/leaderboard/#{leaderboard_with_default_period_set_to_daily.id}.json"
      default_user_score = response.parsed_body["users"][0]["total_score"]

      expect(default_user_score).to eq(daily_user_score)
      expect(default_user_score).not_to eq(regular_user_score)
    end
  end
end
