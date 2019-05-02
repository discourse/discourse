# frozen_string_literal: true

{
  -1 => "d-logo-sketch.png", # Old version
  -2 => "d-logo-sketch-small.png", # Old version
  -3 => "default-favicon.ico", # No longer used
  -4 => "default-apple-touch-icon.png", # No longer used
  -5 => "discourse-logo-sketch.png",
  -6 => "discourse-logo-sketch-small.png",
}.each do |id, filename|
  path = Rails.root.join("public/images/#{filename}")

  Upload.seed do |upload|
    upload.id = id
    upload.user_id = Discourse.system_user.id
    upload.original_filename = filename
    upload.url = "/images/#{filename}"
    upload.filesize = File.size(path)
    upload.extension = File.extname(path)[1..10]
    # Fake an SHA1. We need to have something, so that other parts of the application
    # keep working. But we can't use the real SHA1, in case the seeded file has already
    # been uploaded. Use an underscore to make clash impossible.
    upload.sha1 = "_#{Upload.generate_digest(path)}"[0..Upload::SHA1_LENGTH - 1]
  end
end
