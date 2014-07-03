# Trust level system badges.
trust_level_badges = [
  {id: 1, name: "Basic User", type: 3},
  {id: 2, name: "Regular User", type: 3},
  {id: 3, name: "Leader", type: 2},
  {id: 4, name: "Elder", type: 1}
]

trust_level_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.name = spec[:name]
    b.badge_type_id = spec[:type]
    b.query = Badge::Queries.trust_level(spec[:id])
  end
end

Badge.seed do |b|
  b.id = Badge::Welcome
  b.name = "Welcome"
  b.badge_type_id = 3
  b.multiple_grant = false
  b.target_posts = true
  b.query = Badge::Queries::Welcome
end

Badge.seed do |b|
  b.id = Badge::Autobiographer
  b.name = "Autobiographer"
  b.badge_type_id = 3
  b.multiple_grant = false
  b.query = Badge::Queries::Autobiographer
end

#
# Like system badges.
like_badges = [
  {id: 6, name: "Nice Post", type: 3, multiple: true},
  {id: 7, name: "Good Post", type: 2, multiple: true},
  {id: 8, name: "Great Post", type: 1, multiple: true}
]

like_badges.each do |spec|
  Badge.seed do |b|
    b.id = spec[:id]
    b.name = spec[:name]
    b.badge_type_id = spec[:type]
    b.multiple_grant = spec[:multiple]
    b.target_posts = true
    b.query = Badge::Queries.like_badge(Badge.like_badge_counts[spec[:id]])
  end
end
