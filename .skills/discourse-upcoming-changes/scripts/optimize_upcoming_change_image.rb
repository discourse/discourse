# frozen_string_literal: true

# Usage: bin/rails runner ~/path/to/discourse-upcoming-changes/scripts/optimize_upcoming_change_image.rb <path>
#
# Converts (if needed), resizes, and optimizes an image for use as an upcoming change preview.
# Uses Discourse's ImageMagick integration for format conversion and OptimizedImage for optimization.

path = ARGV[0]

if path.nil? || path.empty?
  puts "Usage: bin/rails runner #{__FILE__} <image_path>"
  exit 1
end

path = File.expand_path(path)

unless File.exist?(path)
  puts "Error: File not found: #{path}"
  exit 1
end

# Detect actual image format using FastImage (not file extension)
image_info = FastImage.new(path)

if image_info.nil?
  puts "Error: Could not determine image format for: #{path}"
  exit 1
end

actual_type = image_info.type.to_s
puts "Optimizing #{File.basename(path)} (detected format: #{actual_type})..."

# Ensure output path ends with .png
output_path = path.sub(/\.[^.]+$/, ".png")

# Convert to PNG if not already PNG format
if actual_type != "png"
  puts "Converting from #{actual_type} to PNG..."

  # Use ImageMagick to convert to PNG (same approach as Discourse's UploadCreator)
  Discourse::Utils.execute_command(
    "magick",
    path,
    "-auto-orient",
    "-background",
    "white",
    output_path,
    failure_message: "Failed to convert image to PNG",
    timeout: 30,
  )

  # Remove original if different from output
  File.delete(path) if path != output_path && File.exist?(path)
  path = output_path
end

# Use OptimizedImage.downsize to resize (max 1200px width, maintain aspect ratio)
OptimizedImage.downsize(path, path, "1200x>")

# Force pngquant optimization for better compression (OptimizedImage skips it for files > 500KB)
FileHelper.optimize_image!(path, allow_pngquant: true)

size = File.size(path)
puts "Done! Final size: #{(size / 1024.0).round(1)}KB"
