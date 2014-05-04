def reset_badge_grant_count(badge)
  badge.grant_count = UserBadge.where(badge_id: badge.id).count
  badge.save!
end

def grant_trust_level_badges_to_user(user)
  return if user.id == Discourse.system_user.id
  Badge.trust_level_badge_ids.each do |badge_id|
    user_badge = UserBadge.where(user_id: user.id, badge_id: badge_id).first
    if user_badge
      # Revoke the badge if the user is not supposed to have it.
      if user.trust_level < badge_id
        user_badge.destroy!
      end
    else
      # Grant the badge if the user is supposed to have it.
      badge = Badge.find(badge_id)
      if user.trust_level >= badge_id
        UserBadge.create!(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now)
      end
    end
  end
end

trust_level_badges = [
  {id: 1, name: "Basic User", type: 3},
  {id: 2, name: "Regular User", type: 3},
  {id: 3, name: "Leader", type: 2},
  {id: 4, name: "Elder", type: 1}
]

backfill_trust_level_badges = false

trust_level_badges.each do |spec|
  backfill_trust_level_badges ||= Badge.where(id: spec[:id]).first.nil?

  Badge.seed do |b|
    b.id = spec[:id]
    b.name = spec[:name]
    b.badge_type_id = spec[:type]
  end
end

if backfill_trust_level_badges
  User.find_each {|user| grant_trust_level_badges_to_user(user) }
  Badge.where(id: Badge.trust_level_badge_ids).each {|badge| reset_badge_grant_count(badge) }
end
