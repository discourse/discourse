# frozen_string_literal: true

# Backfill Discourse group memberships from vBulletin 5.
#
# Run after vbulletin5.rb has completed importing users and groups.
# Reads both usergroupid (primary) and membergroupids (secondary, comma-separated)
# from the vBulletin user table and adds users to the corresponding Discourse groups.
#
# Safe to re-run: existing group_users rows are not duplicated.
# No notification emails are sent (notification_level = 0).
#
# I suspect this is unneeded now
# Usage:
#   su discourse -c 'bundle exec rails runner script/import_scripts/import_group_memberships.rb'

ENV["IMPORT_LIBRARY_ONLY"] = "1"
require_relative "vbulletin5"

importer = ImportScripts::VBulletin.allocate.library_only_init

# After all memberships are created, optionally reset notification_level to 2
# (tracking) for all group_users rows created by this script.
# Set to true once you're done importing and want normal Discourse behaviour.
# Leave false during initial import to avoid sending thousands of notification emails.
RESET_NOTIFICATION_LEVEL = false

# vBulletin group titles to skip entirely - these are system/lifecycle groups
# that don't represent meaningful community membership in Discourse.
IGNORED_GROUP_TITLES = [
  "Guest Users",
  "Registered Users",
  "Users Awaiting Email Confirmation",
  "(COPPA) Users Awaiting Moderation",
  "Banned Users",
  "Administrators",
  "Super Moderators",
].freeze

puts "", "Building vBulletin group id → Discourse group map..."

vb_groups = importer.send(:mysql_query, <<~SQL).to_a
  SELECT usergroupid, title FROM #{ImportScripts::VBulletin::DB_PREFIX}usergroup ORDER BY usergroupid
SQL

group_map = {}
vb_groups.each do |vbg|
  next if IGNORED_GROUP_TITLES.include?(vbg["title"])
  discourse_group_id = GroupCustomField
    .where(name: "import_id", value: vbg["usergroupid"].to_s)
    .pick(:group_id)
  next unless discourse_group_id
  group = Group.find_by(id: discourse_group_id)
  next unless group
  group_map[vbg["usergroupid"]] = group
end

puts "  #{group_map.size} groups eligible for membership import"
puts "  Ignored: #{IGNORED_GROUP_TITLES.join(", ")}"

puts "", "Loading vBulletin users..."
users = importer.send(:mysql_query, <<~SQL).to_a
  SELECT userid, usergroupid, membergroupids
    FROM #{ImportScripts::VBulletin::DB_PREFIX}user
   ORDER BY userid
SQL

total    = users.size
added    = 0
skipped  = 0
no_user  = 0
no_group = 0

users.each_with_index do |vbu, idx|
  print "\r#{idx + 1} / #{total}" if (idx % 500).zero?

  user_id = UserCustomField
    .where(name: "import_id", value: vbu["userid"].to_s)
    .pick(:user_id)
  unless user_id
    no_user += 1
    next
  end

  # Collect all group IDs for this user: primary + secondary
  group_ids = [vbu["usergroupid"]]
  if vbu["membergroupids"].present?
    group_ids += vbu["membergroupids"].split(",").map(&:to_i)
  end
  group_ids.uniq!

  group_ids.each do |vb_gid|
    group = group_map[vb_gid]
    unless group
      no_group += 1
      next
    end

    # Idempotent: skip if already a member
    if GroupUser.where(group_id: group.id, user_id: user_id).exists?
      skipped += 1
      next
    end

    GroupUser.create!(
      group_id:           group.id,
      user_id:            user_id,
      notification_level: 0,  # no notifications - historical backfill
    )
    added += 1
  end
end

puts "", "Group membership import complete:"
puts "  added:                             #{added}"
puts "  skipped (already member):          #{skipped}"
puts "  skipped (no Discourse user):       #{no_user}"
puts "  skipped (group ignored/not found): #{no_group}"

if RESET_NOTIFICATION_LEVEL
  puts "", "Resetting notification_level to 2 (tracking) for all imported group memberships..."
  eligible_group_ids = group_map.values.map(&:id)
  updated = GroupUser
    .where(group_id: eligible_group_ids, notification_level: 0)
    .update_all(notification_level: 2)
  puts "  updated #{updated} group_users rows to notification_level 2"
end
