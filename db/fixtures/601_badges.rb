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
