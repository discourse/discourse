# frozen_string_literal: true

[
  ["Daydreamer", BadgeType::Bronze, 1, false],
  ["Brainstormer", BadgeType::Silver, 5, true],
  ["Innovator", BadgeType::Silver, 15, true],
  ["Visionary", BadgeType::Gold, 25, true],
].each do |name, level, count, allow_title|
  Badge.seed(:name) do |badge|
    badge.name = name
    badge.default_icon = "vote-up-filled"
    badge.badge_type_id = level
    badge.default_badge_grouping_id = BadgeGrouping::Community
    badge.query = DiscourseTopicVoting::BadgeQueries.for_threshold(count)
    badge.listable = true
    badge.target_posts = true
    badge.multiple_grant = true
    badge.default_enabled = false
    badge.default_allow_title = allow_title
    badge.trigger = Badge::Trigger::None
    badge.auto_revoke = true
    badge.show_posts = true
    badge.system = true
  end
end
