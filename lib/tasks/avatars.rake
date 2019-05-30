# frozen_string_literal: true

desc "Refresh all avatars (download missing gravatars, refresh system)"
task "avatars:refresh" => :environment do
  i = 0

  puts "Refreshing avatars"
  puts

  User.find_each do |user|
    begin
      user.refresh_avatar
      user.user_avatar.update_gravatar!
    rescue => e
      puts "", "Failed to refresh avatar for #{user.username}", e, e.backtrace.join("\n")
    end
    putc "." if (i += 1) % 10 == 0
  end

  puts
end

desc "Clean up all avatar thumbnails (use this when the thumbnail algorithm changes)"
task "avatars:clean" => :environment do
  i = 0

  puts "Cleaning up avatar thumbnails"
  puts

  optimized_image_ids = OptimizedImage.where("upload_id IN (SELECT custom_upload_id FROM user_avatars) OR
                        upload_id IN (SELECT gravatar_upload_id FROM user_avatars) OR
                        upload_id IN (SELECT uploaded_avatar_id FROM users)").pluck(:id)

  optimized_image_ids.each do |id|
    begin
      optimized_image = OptimizedImage.find_by(id: id)
      next unless optimized_image.present?
      optimized_image.destroy!
    rescue => e
      puts "", "Failed to cleanup avatar (optimized_image id: #{id})", e, e.backtrace.join("\n")
    end
    putc "." if (i += 1) % 10 == 0
  end

  puts
end
