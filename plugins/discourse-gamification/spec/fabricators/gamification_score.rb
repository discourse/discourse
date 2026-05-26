# frozen_string_literal: true

Fabricator(
  :gamification_leaderboard_score,
  from: DiscourseGamification::GamificationLeaderboardScore,
) do
  leaderboard_id { Fabricate(:gamification_leaderboard).id }
  user_id { Fabricate(:user).id }
  score { 0 }
  date { Date.today }
end
