# Trust level system badges.
trust_level_badges = [
  {id: 1, name: "Basic User", type: 3},
  {id: 2, name: "Regular User", type: 3},
  {id: 3, name: "Leader", type: 2},
  {id: 4, name: "Elder", type: 1}
]

backfill_trust_level_badges = false

trust_level_badges.each do |spec|
  backfill_trust_level_badges ||= Badge.find_by(id: spec[:id]).nil?

  Badge.seed do |b|
    b.id = spec[:id]
    b.name = spec[:name]
    b.badge_type_id = spec[:type]
  end
end

if backfill_trust_level_badges
  puts "Backfilling trust level badges!"


  Badge.trust_level_badge_ids.each do |badge_id|
    sql = <<SQL
    DELETE FROM user_badges
    WHERE badge_id = :badge_id AND
          user_id NOT IN (SELECT id FROM users WHERE trust_level <= :badge_id)
SQL

    User.exec_sql(sql, badge_id: badge_id)

    sql = <<SQL
    INSERT INTO user_badges(badge_id, user_id, granted_at, granted_by_id)
    SELECT :badge_id, id, :now, :system_id
    FROM users
    WHERE trust_level >= :trust_level AND
          id NOT IN (SELECT user_id FROM user_badges WHERE badge_id = :badge_id) AND
          id <> :system_id
SQL
    User.exec_sql(sql, badge_id: badge_id, now: Time.now, system_id: Discourse.system_user.id, trust_level: badge_id)

  end

  Badge.where(id: Badge.trust_level_badge_ids).each {|badge| badge.reset_grant_count! }
end
#
# Like system badges.
like_badges = [
  {id: 5, name: "Welcome", type: 3, multiple: false},
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
  end
end

# Create an example badge if one does not already exist.
if Badge.find_by(id: 101).nil?
  Badge.seed do |b|
    b.id = 101
    b.name = "Example Badge"
    b.badge_type_id = 3
  end
end
