# frozen_string_literal: true

# name: discourse-gamification
# about: Allows admins to create and customize community scoring contests for user accomplishments with leaderboards.
# meta_topic_id: 225916
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-gamification
# required_version: 2.7.0

enabled_site_setting :discourse_gamification_enabled

register_asset "stylesheets/common/leaderboard.scss"
register_asset "stylesheets/desktop/leaderboard.scss", :desktop
register_asset "stylesheets/mobile/leaderboard.scss", :mobile
register_asset "stylesheets/common/leaderboard-info-modal.scss"
register_asset "stylesheets/common/leaderboard-minimal.scss"
register_asset "stylesheets/common/leaderboard-admin.scss"
register_asset "stylesheets/common/gamification-score.scss"

register_svg_icon "crown"
register_svg_icon "award"

module ::DiscourseGamification
  PLUGIN_NAME = "discourse-gamification"
end

require_relative "lib/discourse_gamification/engine"

after_initialize do
  # route: /admin/plugins/discourse-gamification
  add_admin_route(
    "gamification.admin.title",
    "discourse-gamification",
    { use_new_show_route: true },
  )

  require_relative "jobs/scheduled/update_scores_for_ten_days"
  require_relative "jobs/scheduled/update_scores_for_today"
  require_relative "jobs/regular/recalculate_scores"
  require_relative "jobs/regular/generate_leaderboard_positions"
  require_relative "jobs/regular/refresh_leaderboard_positions"
  require_relative "jobs/regular/delete_leaderboard_positions"
  require_relative "jobs/regular/update_stale_leaderboard_positions"
  require_relative "jobs/regular/regenerate_leaderboard_positions"
  require_relative "lib/discourse_gamification/directory_integration"
  require_relative "lib/discourse_gamification/guardian_extension"
  require_relative "lib/discourse_gamification/scorables/scorable"
  require_relative "lib/discourse_gamification/scorables/day_visited"
  require_relative "lib/discourse_gamification/scorables/flag_created"
  require_relative "lib/discourse_gamification/scorables/like_given"
  require_relative "lib/discourse_gamification/scorables/like_received"
  require_relative "lib/discourse_gamification/scorables/post_created"
  require_relative "lib/discourse_gamification/scorables/post_read"
  require_relative "lib/discourse_gamification/scorables/solutions"
  require_relative "lib/discourse_gamification/scorables/time_read"
  require_relative "lib/discourse_gamification/scorables/topic_created"
  require_relative "lib/discourse_gamification/scorables/user_invited"
  require_relative "lib/discourse_gamification/user_extension"
  require_relative "lib/discourse_gamification/scorables/reaction_given"
  require_relative "lib/discourse_gamification/scorables/reaction_received"
  require_relative "lib/discourse_gamification/scorables/chat_reaction_given"
  require_relative "lib/discourse_gamification/scorables/chat_reaction_received"
  require_relative "lib/discourse_gamification/scorables/chat_message_created"
  require_relative "lib/discourse_gamification/recalculate_scores_rate_limiter"
  require_relative "lib/discourse_gamification/leaderboard_cached_view"

  reloadable_patch do |plugin|
    User.prepend(DiscourseGamification::UserExtension)
    Guardian.include(DiscourseGamification::GuardianExtension)
  end

  if respond_to?(:add_directory_column)
    add_directory_column(
      "gamification_score",
      query: DiscourseGamification::DirectoryIntegration.query,
    )
  end

  add_to_serializer(
    :admin_plugin,
    :extras,
    include_condition: -> { self.name == "discourse-gamification" },
  ) do
    {
      gamification_recalculate_scores_remaining:
        DiscourseGamification::RecalculateScoresRateLimiter.remaining,
      gamification_groups:
        Group
          .includes(:flair_upload)
          .all
          .map { |group| BasicGroupSerializer.new(group, root: false, scope: self.scope).as_json },
      gamification_leaderboards:
        DiscourseGamification::GamificationLeaderboard.all.map do |leaderboard|
          LeaderboardSerializer.new(leaderboard, root: false).as_json
        end,
    }
  end

  add_to_serializer(:user_card, :gamification_score) { object.gamification_score }
  add_to_serializer(:site, :default_gamification_leaderboard_id) do
    DiscourseGamification::GamificationLeaderboard.first&.id
  end

  SeedFu.fixture_paths << Rails
    .root
    .join("plugins", "discourse-gamification", "db", "fixtures")
    .to_s

  on(:site_setting_changed) do |name|
    next if name != :score_ranking_strategy

    Jobs.enqueue(::Jobs::RegenerateLeaderboardPositions)
  end

  on(:merging_users) do |source_user, target_user|
    DiscourseGamification::GamificationScore.merge_scores(source_user, target_user)
  end
end
