# frozen_string_literal: true

# Usage: bin/rails runner ~/path/to/discourse-upcoming-changes/scripts/optimize_upcoming_change_image.rb <path>
#
# Converts (if needed), resizes, and optimizes an image for use as an upcoming change preview.
# Uses Safe Image for format conversion and optimization.

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

# Detect actual image format using Safe Image (not file extension)
image_info =
  begin
    DiscourseImage.info(path)
  rescue SafeImage::Error, ArgumentError
    nil
  end

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

  DiscourseImage.convert(path, output_path, format: "png", optimize: false)

  # Remove original if different from output
  File.delete(path) if path != output_path && File.exist?(path)
  path = output_path
end

# Use OptimizedImage.downsize to resize (max 1200px width, maintain aspect ratio)
OptimizedImage.downsize(path, path, "1200x>")

# Force lossy PNG optimization for better compression (OptimizedImage only enables it for small files)
FileHelper.optimize_image!(path, allow_pngquant: true)

size = File.size(path)
puts "Done! Final size: #{(size / 1024.0).round(1)}KB"
