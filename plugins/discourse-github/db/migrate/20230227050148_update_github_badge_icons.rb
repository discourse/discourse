# frozen_string_literal: true

class UpdateGithubBadgeIcons < ActiveRecord::Migration[7.0]
  def change
    badges = [
      DiscourseGithubPlugin::GithubBadges::BADGE_NAME_BRONZE,
      DiscourseGithubPlugin::GithubBadges::BADGE_NAME_SILVER,
      DiscourseGithubPlugin::GithubBadges::BADGE_NAME_GOLD,
      DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_BRONZE,
      DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_SILVER,
      DiscourseGithubPlugin::GithubBadges::COMMITTER_BADGE_NAME_GOLD,
    ]
    execute <<~SQL
      UPDATE badges
      SET icon = 'fab-git-alt'
      WHERE
        name IN (#{badges.map { |b| "'#{b}'" }.join(",")})
        AND icon = 'fa-certificate'
    SQL
  end
end
