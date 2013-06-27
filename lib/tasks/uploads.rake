require "digest/sha1"

task "uploads:backfill_shas" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Backfilling #{db}"
    Upload.select([:id, :sha, :url]).find_each do |u|
      if u.sha.nil?
        putc "."
        path = "#{Rails.root}/public/#{u.url}"
        sha = Digest::SHA1.file(path).hexdigest
        begin
          Upload.update_all ["sha = ?", sha], ["id = ?", u.id]
        rescue ActiveRecord::RecordNotUnique
          # not a big deal if we've got a few duplicates
        end
      end
    end
  end
  puts "done"
end
