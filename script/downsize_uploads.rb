# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

# Supported ENV arguments:
#
# VERBOSE=1
# Shows debug information.
#
# INTERACTIVE=1
# Shows debug information and pauses for input on issues.
#
# WORKER_ID/WORKER_COUNT
# When running the script on a single forum in multiple terminals.
# For example, if you want 4 concurrent scripts use WORKER_COUNT=4
# and WORKER_ID from 0 to 3

MIN_IMAGE_PIXELS = 500_000 # 0.5 megapixels
DEFAULT_IMAGE_PIXELS = 1_000_000 # 1 megapixel

MAX_IMAGE_PIXELS = [
  ARGV[0]&.to_i || DEFAULT_IMAGE_PIXELS,
  MIN_IMAGE_PIXELS
].max

ENV["VERBOSE"] = "1" if ENV["INTERACTIVE"]

def log(*args)
  puts(*args) if ENV["VERBOSE"]
end

def process_uploads
  puts "", "Downsizing images to no more than #{MAX_IMAGE_PIXELS} pixels"

  dimensions_count = 0
  downsized_count = 0

  scope = Upload
    .by_users
    .with_no_non_post_relations
    .where("LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')")

  scope = scope.where(<<-SQL, MAX_IMAGE_PIXELS)
    COALESCE(width, 0) = 0 OR
    COALESCE(height, 0) = 0 OR
    COALESCE(thumbnail_width, 0) = 0 OR
    COALESCE(thumbnail_height, 0) = 0 OR
    width * height > ?
  SQL

  if ENV["WORKER_ID"] && ENV["WORKER_COUNT"]
    scope = scope.where("id % ? = ?", ENV["WORKER_COUNT"], ENV["WORKER_ID"])
  end

  skipped = 0
  total_count = scope.count
  puts "Uploads to process: #{total_count}"

  scope.find_each.with_index do |upload, index|
    progress = (index * 100.0 / total_count).round(1)

    log "\n"
    print "\r#{progress}% Fixed dimensions: #{dimensions_count} Downsized: #{downsized_count} Skipped: #{skipped} (upload id: #{upload.id})"
    log "\n"

    path = if upload.local?
      Discourse.store.path_for(upload)
    else
      (Discourse.store.download(upload, max_file_size_kb: 100.megabytes) rescue nil)&.path
    end

    unless path
      log "No image path"
      skipped += 1
      next
    end

    begin
      w, h = FastImage.size(path, raise_on_failure: true)
    rescue FastImage::UnknownImageType
      log "Unknown image type"
      skipped += 1
      next
    rescue FastImage::SizeNotFound
      log "Size not found"
      skipped += 1
      next
    end

    if !w || !h
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    ww, hh = ImageSizer.resize(w, h)

    if w == 0 || h == 0 || ww == 0 || hh == 0
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    upload.attributes = {
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh,
      filesize: File.size(path)
    }

    if upload.changed?
      log "Correcting the upload dimensions"
      log "Before: #{upload.width_was}x#{upload.height_was} #{upload.thumbnail_width_was}x#{upload.thumbnail_height_was} (#{upload.filesize_was})"
      log "After:  #{w}x#{h} #{ww}x#{hh} (#{upload.filesize})"

      dimensions_count += 1
      upload.save!
    end

    if w * h < MAX_IMAGE_PIXELS
      log "Image size within allowed range"
      skipped += 1
      next
    end

    result = ShrinkUploadedImage.new(
      upload: upload,
      path: path,
      max_pixels: MAX_IMAGE_PIXELS,
      verbose: ENV["VERBOSE"],
      interactive: ENV["INTERACTIVE"]
    ).perform

    if result
      downsized_count += 1
    else
      skipped += 1
    end
  end

  STDIN.beep
  puts "", "Done", Time.zone.now
end

process_uploads
