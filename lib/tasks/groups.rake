# bulk grant badge to members of a specific group
task "groups:grant_badge", [:group_id, :badge_id] => [:environment] do |_, args|
  group_id = args[:group_id]
  badge_id = args[:badge_id]

  if !group_id || !badge_id
    puts "ERROR: Expecting groups:grant_badge[group_id,badge_id]"
    exit 1
  end

  group = Group.find(group_id)
  badge = Badge.find(badge_id)

  if group.present? && badge.present?
    puts "Granting badge '#{badge.name}' to all users in group '#{group.name}'..."

    count = 0
    group.users.each do |user|
      begin
        BadgeGranter.grant(badge, user)
      rescue => e
        puts "", "Failed to grant badge to #{user.username}", e, e.backtrace.join("\n")
      end
      putc "." if (count += 1) % 5 == 0
    end
  end

  puts "", "Done! Badge granted to #{count} members.", ""
end
