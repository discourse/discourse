desc "re-generate avatars"
task "avatars:regenerate" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Generating avatars for: #{db}"

    User.select(:uploaded_avatar_id).where("uploaded_avatar_id IS NOT NULL").all.each do |u|
      Jobs.enqueue(:generate_avatars, upload_id: u.uploaded_avatar_id)
      putc "."
    end

  end
  puts "\ndone."
end
