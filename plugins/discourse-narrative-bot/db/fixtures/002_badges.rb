# frozen_string_literal: true

Badge
  .where(name: 'Complete New User Track')
  .update_all(name: DiscourseNarrativeBot::NewUserNarrative::BADGE_NAME)

Badge
  .where(name: 'Complete Discobot Advanced User Track')
  .update_all(name: DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME)

new_user_narrative_badge = Badge.find_by(name: DiscourseNarrativeBot::NewUserNarrative::BADGE_NAME)

unless new_user_narrative_badge
  new_user_narrative_badge = Badge.create!(
    name: DiscourseNarrativeBot::NewUserNarrative::BADGE_NAME,
    badge_type_id: 3
  )
end

advanced_user_narrative_badge = Badge.find_by(name: DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME)

unless advanced_user_narrative_badge
  advanced_user_narrative_badge = Badge.create!(
    name: DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME,
    badge_type_id: 2
  )
end

badge_grouping = BadgeGrouping.find(1)

[
  [new_user_narrative_badge, I18n.t('badges.certified.description')],
  [advanced_user_narrative_badge, I18n.t('badges.licensed.description')]
].each do |badge, description|

  badge.update!(
    badge_grouping: badge_grouping,
    description: description,
    system: true
  )
end
