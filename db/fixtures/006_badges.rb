
BadgeGrouping.seed do |g|
  g.id = BadgeGrouping::GettingStarted
  g.name = "Getting Started"
  g.default_position = 10
end

BadgeGrouping.seed do |g|
  g.id = BadgeGrouping::Community
  g.name = "Community"
  g.default_position = 11
end

BadgeGrouping.seed do |g|
  g.id = BadgeGrouping::Posting
  g.name = "Posting"
  g.default_position = 12
end

BadgeGrouping.seed do |g|
  g.id = BadgeGrouping::TrustLevel
  g.name = "Trust Level"
  g.default_position = 13
end

BadgeGrouping.seed do |g|
  g.id = BadgeGrouping::Other
  g.name = "Other"
  g.default_position = 14
end

# BUGFIX
Badge.exec_sql "UPDATE badges
                SET badge_grouping_id = -1
                WHERE NOT EXISTS (
                  SELECT 1 FROM badge_groupings g
                  WHERE g.id = badge_grouping_id
                ) OR (id < 100 AND badge_grouping_id = #{BadgeGrouping::Other} )"

# Trust level system badges.
trust_level_badges = [
  {id: 1, name: "Basic User", type: BadgeType::Bronze},
  {id: 2, name: "Member", type: BadgeType::Bronze},
  {id: 3, name: "Regular", type: BadgeType::Silver},
  {id: 4, name: "Leader", type: BadgeType::Gold}
]

trust_level_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.default_name = spec[:name]
    b.badge_type_id = spec[:type]
    b.query = Badge::Queries.trust_level(spec[:id])
    b.default_badge_grouping_id = BadgeGrouping::TrustLevel
    b.trigger = Badge::Trigger::TrustLevelChange

    # allow title for tl3 and above
    b.default_allow_title = spec[:id] > 2
    b.default_icon = "fa-user"
    b.system = true
  end
end

Badge.seed do |b|
  b.id = Badge::Reader
  b.default_name = "Reader"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = Badge::Queries::Reader
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.auto_revoke = false
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::ReadGuidelines
  b.default_name = "Read Guidelines"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = Badge::Queries::ReadGuidelines
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::UserChange
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::FirstLink
  b.default_name = "First Link"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = Badge::Queries::FirstLink
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::PostRevision
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::FirstQuote
  b.default_name = "First Quote"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = Badge::Queries::FirstQuote
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::PostRevision
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::FirstLike
  b.default_name = "First Like"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = Badge::Queries::FirstLike
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::PostAction
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::FirstFlag
  b.default_name = "First Flag"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = false
  b.query = Badge::Queries::FirstFlag
  b.default_badge_grouping_id = BadgeGrouping::Community
  b.trigger = Badge::Trigger::PostAction
  b.auto_revoke = false
  b.system = true
end

[
  [Badge::Promoter,"Promoter",BadgeType::Bronze,1,0],
  [Badge::Campaigner,"Campaigner",BadgeType::Silver,3,1],
  [Badge::Champion,"Champion",BadgeType::Gold,5,2],
].each do |id, name, type, count, trust_level|
  Badge.seed do |b|
    b.id = id
    b.default_name = name
    b.default_icon = "fa-user-plus"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = Badge::Queries.invite_badge(count,trust_level)
    b.default_badge_grouping_id = BadgeGrouping::Community
    # daily is good enough
    b.trigger = Badge::Trigger::None
    b.auto_revoke = true
    b.system = true
  end
end

Badge.seed do |b|
  b.id = Badge::FirstShare
  b.default_name = "First Share"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = Badge::Queries::FirstShare
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  # don't trigger for now, its too expensive
  b.trigger = Badge::Trigger::None
  b.system = true
end

[
 [Badge::NiceShare, "Nice Share", BadgeType::Bronze, 25],
 [Badge::GoodShare, "Good Share", BadgeType::Silver, 300],
 [Badge::GreatShare, "Great Share", BadgeType::Gold, 1000],
].each do |spec|

  id, name, level, count = spec
  Badge.seed do |b|
    b.id = id
    b.default_name = name
    b.badge_type_id = level
    b.multiple_grant = true
    b.target_posts = true
    b.show_posts = true
    b.query = Badge::Queries.sharing_badge(count)
    b.default_badge_grouping_id = BadgeGrouping::Community
    # don't trigger for now, its too expensive
    b.trigger = Badge::Trigger::None
    b.system = true
  end
end

Badge.seed do |b|
  b.id = Badge::Welcome
  b.default_name = "Welcome"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = Badge::Queries::Welcome
  b.default_badge_grouping_id = BadgeGrouping::Community
  b.trigger = Badge::Trigger::PostAction
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::Autobiographer
  b.default_name = "Autobiographer"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.query = Badge::Queries::Autobiographer
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::UserChange
  b.system = true
end

Badge.seed do |b|
  b.id = Badge::Editor
  b.default_name = "Editor"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.query = Badge::Queries::Editor
  b.default_badge_grouping_id = BadgeGrouping::Community
  b.trigger = Badge::Trigger::PostRevision
  b.system = true
end

#
# Like system badges.
like_badges = [
  {id: Badge::NicePost, name: "Nice Post", type: BadgeType::Bronze},
  {id: Badge::GoodPost, name: "Good Post", type: BadgeType::Silver},
  {id: Badge::GreatPost, name: "Great Post", type: BadgeType::Gold},
  {id: Badge::NiceTopic, name: "Nice Topic", type: BadgeType::Bronze, topic: true},
  {id: Badge::GoodTopic, name: "Good Topic", type: BadgeType::Silver, topic: true},
  {id: Badge::GreatTopic, name: "Great Topic", type: BadgeType::Gold, topic: true}
]

like_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.default_name = spec[:name]
    b.badge_type_id = spec[:type]
    b.multiple_grant = true
    b.target_posts = true
    b.show_posts = true
    b.query = Badge::Queries.like_badge(Badge.like_badge_counts[spec[:id]], spec[:topic])
    b.default_badge_grouping_id = BadgeGrouping::Posting
    b.trigger = Badge::Trigger::PostAction
    b.system = true
  end
end

Badge.seed do |b|
  b.id = Badge::OneYearAnniversary
  b.default_name = "Anniversary"
  b.default_icon = "fa-clock-o"
  b.badge_type_id = BadgeType::Silver
  b.query = Badge::Queries::OneYearAnniversary
  b.default_badge_grouping_id = BadgeGrouping::Community
  b.trigger = Badge::Trigger::None
  b.auto_revoke = false
  b.system = true
end

[
 [Badge::PopularLink, "Popular Link", BadgeType::Bronze, 50],
 [Badge::HotLink,     "Hot Link",     BadgeType::Silver, 300],
 [Badge::FamousLink,  "Famous Link",  BadgeType::Gold,   1000],
].each do |spec|
  id, name, level, count = spec
  Badge.seed do |b|
    b.id = id
    b.default_name = name
    b.badge_type_id = level
    b.multiple_grant = true
    b.target_posts = true
    b.show_posts = true
    b.query = Badge::Queries.linking_badge(count)
    b.default_badge_grouping_id = BadgeGrouping::Community
    # don't trigger for now, its too expensive
    b.trigger = Badge::Trigger::None
    b.system = true
  end
end

Badge.where("NOT system AND id < 100").each do |badge|
  new_id = [Badge.maximum(:id) + 1, 100].max
  old_id = badge.id
  badge.update_columns(id: new_id)
  UserBadge.where(badge_id: old_id).update_all(badge_id: new_id)
end
