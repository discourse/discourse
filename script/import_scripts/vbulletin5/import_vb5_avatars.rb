# frozen_string_literal: true

# Standalone avatar importer for vBulletin 5 -> Discourse.
#
# Uses vbulletin5.rb
#
# Usage:
#   bundle exec ruby script/import_scripts/vbulletin5/import_vb5_avatars.rb
#
# If you want to force it to reprocess everyone, even thought it's been done once:
#   FORCE=1 bundle exec ruby script/import_scripts/vbulletin5/import_vb5_avatars.rb

ENV["IMPORT_LIBRARY_ONLY"] = "1"
require_relative "vbulletin5"

# Set FORCE=1 to re-import avatars even for users who already have one.
FORCE = ENV["FORCE"].present?

importer = ImportScripts::VBulletin.allocate.library_only_init

puts "", "importing avatars..."

avatars = importer.send(:mysql_query, <<~SQL).to_a
  SELECT userid, filename, filedata, LENGTH(filedata) AS dbsize
    FROM #{ImportScripts::VBulletin::DB_PREFIX}customavatar
   ORDER BY userid, dateline DESC
SQL

seen               = Set.new
skipped_no_user    = 0
skipped_has_avatar = 0
skipped_no_file    = 0
failed             = 0
imported           = 0

avatars.each do |row|
  userid = row["userid"]
  next if seen.include?(userid)
  seen << userid

  user_id = UserCustomField.where(name: "import_id", value: userid.to_s).pick(:user_id)
  unless user_id
    skipped_no_user += 1
    next
  end

  user = User.find_by(id: user_id)
  unless user
    skipped_no_user += 1
    next
  end

  if user.uploaded_avatar_id.present? && !FORCE
    skipped_has_avatar += 1
    next
  end

  upload = nil
  file   = nil

  # This will prioritize finding files that match the right filename pattern. See
  # the definition of find_avatar_file() in vbulletin5.rb for the rationale. If no
  # file is found, write data from the database into a file of the given name, then
  # try to upload it. I've had situations where dbsize was non-zero, but there is no
  # filedata in the database. This will create corrupted JPEG or PNG files and upload
  # them.
  begin
    fs_path = importer.send(:find_avatar_file, row["filename"])

    if fs_path
      upload = importer.send(:create_upload, user.id, fs_path, File.basename(fs_path))
    elsif row["dbsize"].to_i > 0
      file = Tempfile.new(["avatar#{userid}", File.extname(row["filename"])])
      file.binmode
      file.write(row["filedata"].b)
      file.rewind
      upload = UploadCreator.new(file, row["filename"]).create_for(user.id)
    else
      puts "  missing: no file on disk and no DB blob for userid #{userid} (#{row["filename"]})"
      skipped_no_file += 1
      next
    end

    unless upload&.persisted?
      puts "  WARNING: upload failed for userid #{userid} (#{row["filename"]})"
      failed += 1
      next
    end

    user.create_user_avatar unless user.user_avatar
    user.user_avatar.update!(custom_upload_id: upload.id)
    user.update!(uploaded_avatar_id: upload.id)
    imported += 1

  rescue StandardError => e
    puts "  ERROR userid #{userid}: #{e.message.lines.first&.strip}"
    failed += 1
  ensure
    file&.close
    file&.unlink rescue nil
  end
end

puts "", "Avatar import complete:"
puts "  imported:                     #{imported}"
puts "  skipped (no user):            #{skipped_no_user}"
puts "  skipped (has avatar already): #{skipped_has_avatar}"
puts "  skipped (file missing):       #{skipped_no_file}"
puts "  failed:                       #{failed}"
