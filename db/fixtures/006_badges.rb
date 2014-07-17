# Trust level system badges.
trust_level_badges = [
  {id: 1, name: "Basic User", type: BadgeType::Bronze},
  {id: 2, name: "Regular User", type: BadgeType::Bronze},
  {id: 3, name: "Leader", type: BadgeType::Silver},
  {id: 4, name: "Elder", type: BadgeType::Gold}
]

trust_level_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.default_name = spec[:name]
    b.badge_type_id = spec[:type]
    b.query = Badge::Queries.trust_level(spec[:id])

    # allow title for leader and elder
    b.allow_title = spec[:id] > 2
  end
end

Badge.seed do |b|
  b.id = Badge::Reader
  b.default_name = "Reader"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.query = Badge::Queries::Reader
  b.auto_revoke = false
end

Badge.seed do |b|
  b.id = Badge::ReadGuidelines
  b.default_name = "Read Guidelines"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.query = Badge::Queries::ReadGuidelines
end

Badge.seed do |b|
  b.id = Badge::FirstLink
  b.default_name = "First Link"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::FirstLink
end

Badge.seed do |b|
  b.id = Badge::FirstQuote
  b.default_name = "First Quote"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::FirstQuote
end

Badge.seed do |b|
  b.id = Badge::FirstLike
  b.default_name = "First Like"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::FirstLike
end

Badge.seed do |b|
  b.id = Badge::FirstFlag
  b.default_name = "First Flag"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.query = Badge::Queries::FirstFlag
end

Badge.seed do |b|
  b.id = Badge::FirstShare
  b.default_name = "First Share"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::FirstShare
end

Badge.seed do |b|
  b.id = Badge::Welcome
  b.default_name = "Welcome"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::Welcome
end

Badge.seed do |b|
  b.id = Badge::Autobiographer
  b.default_name = "Autobiographer"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.query = Badge::Queries::Autobiographer
end

Badge.seed do |b|
  b.id = Badge::Editor
  b.default_name = "Editor"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.query = Badge::Queries::Editor
end

#
# Like system badges.
like_badges = [
  {id: 6, name: "Nice Post", type: BadgeType::Bronze, multiple: true},
  {id: 7, name: "Good Post", type: BadgeType::Silver, multiple: true},
  {id: 8, name: "Great Post", type: BadgeType::Gold, multiple: true}
]

like_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.default_name = spec[:name]
    b.badge_type_id = spec[:type]
    b.multiple_grant = spec[:multiple]
    b.target_posts = true
    b.query = Badge::Queries.like_badge(Badge.like_badge_counts[spec[:id]])
  end
end
