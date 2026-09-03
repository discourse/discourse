# frozen_string_literal: true

voice_badge_group = "Voice"

BadgeGrouping.seed(:name) do |g|
  g.name = voice_badge_group
  g.default_position = 15
end

voice_grouping = BadgeGrouping.find_by(name: voice_badge_group)

duration_sql = "EXTRACT(EPOCH FROM (COALESCE(left_at, CURRENT_TIMESTAMP) - joined_at))"

co_presence_distinct_partners = lambda { |min_count| <<~SQL }
    SELECT uid user_id, current_timestamp granted_at FROM (
      SELECT user_id_1 AS uid, user_id_2 AS partner_id
      FROM voice_co_presences
      GROUP BY user_id_1, user_id_2
      HAVING SUM(total_seconds) >= 300
      UNION ALL
      SELECT user_id_2 AS uid, user_id_1 AS partner_id
      FROM voice_co_presences
      GROUP BY user_id_2, user_id_1
      HAVING SUM(total_seconds) >= 300
    ) sub
    GROUP BY uid
    HAVING COUNT(*) >= #{min_count}
  SQL

co_presence_with_one_partner = lambda { |min_seconds| <<~SQL }
    SELECT DISTINCT uid user_id, current_timestamp granted_at FROM (
      SELECT user_id_1 AS uid
      FROM voice_co_presences
      GROUP BY user_id_1, user_id_2
      HAVING SUM(total_seconds) >= #{min_seconds}
      UNION ALL
      SELECT user_id_2 AS uid
      FROM voice_co_presences
      GROUP BY user_id_1, user_id_2
      HAVING SUM(total_seconds) >= #{min_seconds}
    ) sub
  SQL

loyalty_query = lambda { |min_days| <<~SQL }
    SELECT DISTINCT user_id, current_timestamp granted_at FROM (
      SELECT user_id, room_id
      FROM voice_sessions
      GROUP BY user_id, room_id
      HAVING COUNT(DISTINCT DATE(joined_at)) >= #{min_days}
    ) sub
  SQL

# -- Welcome (instant) --

Badge.seed(:name) do |b|
  b.name = "Mic Check"
  b.default_icon = "microphone"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

# -- Airtime (scheduled) --

{
  "Rookie" => [BadgeType::Bronze, 1.hour.to_i],
  "Chatterbox" => [BadgeType::Silver, 10.hours.to_i],
  "Silver Tongue" => [BadgeType::Gold, 100.hours.to_i],
}.each do |name, (type, threshold)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = "clock"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = <<~SQL
      SELECT user_id, current_timestamp granted_at
      FROM voice_sessions
      GROUP BY user_id
      HAVING SUM(#{duration_sql}) >= #{threshold}
    SQL
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Networker (instant: Icebreaker, scheduled: Social Butterfly, Life of the Party) --

Badge.seed(:name) do |b|
  b.name = "Icebreaker"
  b.default_icon = "handshake"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

{
  "Social Butterfly" => [BadgeType::Silver, 10],
  "Life of the Party" => [BadgeType::Gold, 50],
}.each do |name, (type, count)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = "users"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = co_presence_distinct_partners.call(count)
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Bonding (scheduled) --

{
  "Familiar Face" => [BadgeType::Bronze, 2.hours.to_i],
  "Inner Circle" => [BadgeType::Silver, 10.hours.to_i],
  "Partners in Crime" => [BadgeType::Gold, 50.hours.to_i],
}.each do |name, (type, threshold)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = "user-group"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = co_presence_with_one_partner.call(threshold)
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Exploration (scheduled) --

{
  "Explorer" => [BadgeType::Bronze, 5],
  "Nomad" => [BadgeType::Silver, 20],
  "Omnipresent" => [BadgeType::Gold, 50],
}.each do |name, (type, count)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = "compass"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = <<~SQL
      SELECT user_id, current_timestamp granted_at
      FROM voice_sessions
      GROUP BY user_id
      HAVING COUNT(DISTINCT room_id) >= #{count}
    SQL
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Loyalty (scheduled) --

{
  "Patron" => [BadgeType::Bronze, 10],
  "Barfly" => [BadgeType::Silver, 30],
  "The Mayor" => [BadgeType::Gold, 100],
}.each do |name, (type, days)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = "calendar"
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = loyalty_query.call(days)
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Hosting (instant: Host, scheduled: Crowd Puller, Master of Ceremonies) --

Badge.seed(:name) do |b|
  b.name = "Host"
  b.default_icon = "house"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

{
  "Crowd Puller" => [BadgeType::Silver, 50, "bullhorn"],
  "Master of Ceremonies" => [BadgeType::Gold, 500, "star"],
}.each do |name, (type, count, icon)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = icon
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = <<~SQL
      SELECT r.creator_id user_id, current_timestamp granted_at
      FROM voice_rooms r
      JOIN voice_sessions s ON s.room_id = r.id
      GROUP BY r.creator_id
      HAVING COUNT(s.id) >= #{count}
    SQL
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Inviting (instant: Plus One, scheduled: Connector, People Magnet) --

Badge.seed(:name) do |b|
  b.name = "Plus One"
  b.default_icon = "user-plus"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

{
  "Connector" => [BadgeType::Silver, 10, "circle-nodes"],
  "People Magnet" => [BadgeType::Gold, 50, "magnet"],
}.each do |name, (type, count, icon)|
  Badge.seed(:name) do |b|
    b.name = name
    b.default_icon = icon
    b.badge_type_id = type
    b.multiple_grant = false
    b.target_posts = false
    b.show_posts = false
    b.query = <<~SQL
      SELECT invited_by_id user_id, current_timestamp granted_at
      FROM voice_invites
      WHERE redeemed_at IS NOT NULL
      GROUP BY invited_by_id
      HAVING COUNT(DISTINCT user_id) >= #{count}
    SQL
    b.default_badge_grouping_id = voice_grouping.id
    b.trigger = Badge::Trigger::None
    b.default_enabled = false
    b.default_allow_title = type == BadgeType::Gold
    b.system = true
  end
end

# -- Standalone --

Badge.seed(:name) do |b|
  b.name = "Night Owl"
  b.default_icon = "moon"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

Badge.seed(:name) do |b|
  b.name = "Early Bird"
  b.default_icon = "sun"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

Badge.seed(:name) do |b|
  b.name = "Packed House"
  b.default_icon = "people-group"
  b.badge_type_id = BadgeType::Silver
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

Badge.seed(:name) do |b|
  b.name = "Weekend Warrior"
  b.default_icon = "calendar-week"
  b.badge_type_id = BadgeType::Silver
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = <<~SQL
    SELECT user_id, current_timestamp granted_at
    FROM voice_sessions
    WHERE EXTRACT(DOW FROM joined_at) IN (0, 6)
    GROUP BY user_id
    HAVING SUM(#{duration_sql}) >= #{5.hours.to_i}
  SQL
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.system = true
end

Badge.seed(:name) do |b|
  b.name = "Marathoner"
  b.default_icon = "trophy"
  b.badge_type_id = BadgeType::Gold
  b.multiple_grant = false
  b.target_posts = false
  b.show_posts = false
  b.query = nil
  b.default_badge_grouping_id = voice_grouping.id
  b.trigger = Badge::Trigger::None
  b.default_enabled = false
  b.default_allow_title = true
  b.system = true
end
