# frozen_string_literal: true

RSpec.describe DiscourseGamification::AdminGamificationLeaderboardController do
  fab!(:admin)

  before do
    SiteSetting.discourse_gamification_enabled = true
    sign_in(admin)
  end

  describe "#create" do
    it "creates leaderboard and enqueues generation of positions" do
      expect(Jobs::GenerateLeaderboardPositions.jobs.size).to eq(0)

      expect do
        post "/admin/plugins/gamification/leaderboard.json",
             params: {
               name: "Test",
               created_by_id: admin.id,
             }
      end.to change { DiscourseGamification::GamificationLeaderboard.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include("name" => "Test", "created_by_id" => admin.id)

      job_data = Jobs::GenerateLeaderboardPositions.jobs.first["args"].first
      expect(job_data).to include("leaderboard_id" => response.parsed_body["id"])
    end
  end

  describe "#update" do
    it "updates leaderboard and enqueues positions refresh" do
      leaderboard = Fabricate(:gamification_leaderboard, created_by_id: admin.id)

      expect(Jobs::RefreshLeaderboardPositions.jobs.size).to eq(0)

      put "/admin/plugins/gamification/leaderboard/#{leaderboard.id}.json",
          params: {
            name: "New Name",
          }

      expect(response.status).to eq(200)
      expect(leaderboard.reload.name).to eq("New Name")

      job_data = Jobs::RefreshLeaderboardPositions.jobs.first["args"].first
      expect(job_data).to include("leaderboard_id" => leaderboard.id)
    end
  end

  describe "destroy" do
    it "deletes leaderboard and enqueues deletion of positions" do
      leaderboard = Fabricate(:gamification_leaderboard, created_by_id: admin.id)

      delete "/admin/plugins/gamification/leaderboard/#{leaderboard.id}.json"

      expect { leaderboard.reload }.to raise_error(ActiveRecord::RecordNotFound)

      job_data = Jobs::DeleteLeaderboardPositions.jobs.first["args"].first
      expect(job_data).to include("leaderboard_id" => leaderboard.id)
    end
  end

  describe "#recalculate_scores" do
    it "enqueues the job with 'since' date" do
      put "/admin/plugins/gamification/recalculate-scores.json", params: { from_date: 10.days.ago }
      expect(response.status).to eq(200)
      expect(Jobs::RecalculateScores.jobs.size).to eq(1)

      job_data = Jobs::RecalculateScores.jobs.first["args"].first
      expect(Date.parse(job_data["since"])).to eq(10.days.ago.midnight)
    end

    it "does not enqueue the job with invalid 'since' date" do
      put "/admin/plugins/gamification/recalculate-scores.json",
          params: {
            from_date: 1.day.from_now,
          }
      expect(response.status).to eq(400)
      expect(Jobs::RecalculateScores.jobs.size).to eq(0)
    end
  end
end
