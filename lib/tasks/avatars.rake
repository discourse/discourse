desc "Rebuild all system avatars"
task "avatars:rebuild_system" => :environment do
  i = 0
  puts "Regenerating system avatars"
  puts
  UserAvatar.find_each do |a|
    a.update_system_avatar!
    putc "." if (i+=1)%10 == 0
  end
  puts
end

desc "Refresh all avatars (download missing gravatars, refresh system)"
task "avatars:refresh" => :environment do
  i = 0
  puts "Refreshing avatars"
  puts
  User.find_each do |user|
    user.refresh_avatar
    user.user_avatar.update_system_avatar!
    putc "." if (i+=1)%10 == 0
  end
  puts
end
