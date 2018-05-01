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

  OptimizedImage.where("upload_id IN (SELECT custom_upload_id FROM user_avatars) OR
                        upload_id IN (SELECT gravatar_upload_id FROM user_avatars) OR
                        upload_id IN (SELECT uploaded_avatar_id FROM users)")
    .find_each do |optimized_image|
    begin
      optimized_image.destroy!
    rescue
      # skip
    end
    putc "." if (i += 1) % 10 == 0
  end

  puts
end
