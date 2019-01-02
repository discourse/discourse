{
  -1 => "d-logo-sketch.png",
  -2 => "d-logo-sketch-small.png",
  -3 => "default-favicon.ico",
  -4 => "default-apple-touch-icon.png"
}.each do |id, filename|
  path = Rails.root.join("public/images/#{filename}")

  Upload.seed do |upload|
    upload.id = id
    upload.user_id = Discourse.system_user.id
    upload.original_filename = filename
    upload.url = "/images/#{filename}"
    upload.filesize = File.size(path)
    upload.extension = File.extname(path)[1..10]
  end
end
