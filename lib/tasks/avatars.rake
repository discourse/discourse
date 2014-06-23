desc "Refresh all avatars (download missing gravatars, refresh system)"
task "avatars:refresh" => :environment do
  i = 0
  puts "Refreshing avatars"
  puts
  User.find_each do |user|
    user.refresh_avatar
    user.user_avatar.update_gravatar!
    putc "." if (i += 1) % 10 == 0
  end
  puts
end

desc "Clean up all avatar thumbnails (use this when the thumbnail algorithm changes)"
task "avatars:clean" => :environment do
  i = 0
  puts "Cleaning up avatar thumbnails"
  puts
  custom_upload_ids = UserAvatar.where.not(custom_upload_id: nil).pluck(:custom_upload_id)
  OptimizedImage.where("upload_id IN (?)", custom_upload_ids).find_each do |optimized_image|
    optimized_image.destroy!
    putc "." if (i += 1) % 10 == 0
  end
  puts
end
