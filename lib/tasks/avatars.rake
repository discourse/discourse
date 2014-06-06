desc "Refresh all avatars (download missing gravatars, refresh system)"
task "avatars:refresh" => :environment do
  i = 0
  puts "Refreshing avatars"
  puts
  User.find_each do |user|
    user.refresh_avatar
    user.user_avatar.update_gravatar!
    putc "." if (i+=1)%10 == 0
  end
  puts
end
