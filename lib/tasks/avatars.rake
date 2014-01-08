desc "re-generate avatars"
task "avatars:regenerate" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Generating avatars for: #{db}"
    next unless SiteSetting.allow_uploaded_avatars
    User.where("uploaded_avatar_id IS NOT NULL").find_each do |u|
      Jobs.enqueue(:generate_avatars, upload_id: u.uploaded_avatar_id, user_id: u.id)
      putc "."
    end
  end
  puts "\ndone."
end
