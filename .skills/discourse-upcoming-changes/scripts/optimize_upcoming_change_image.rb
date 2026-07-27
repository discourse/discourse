# frozen_string_literal: true

# Usage: bin/rails runner ~/path/to/discourse-upcoming-changes/scripts/optimize_upcoming_change_image.rb <path>
#
# Converts (if needed), resizes, and optimizes an image for use as an upcoming change preview.

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

begin
  actual_type = DiscourseImage.type(path).to_s
rescue DiscourseImage::Error
  puts "Error: Could not determine image format for: #{path}"
  exit 1
end
puts "Optimizing #{File.basename(path)} (detected format: #{actual_type})..."

# Ensure output path ends with .png
output_path = path.sub(/\.[^.]+$/, ".png")

# Convert to PNG if not already PNG format
if actual_type != "png"
  puts "Converting from #{actual_type} to PNG..."

  DiscourseImage.convert(input: path, output: output_path, timeout: 30)

  # Remove original if different from output
  File.delete(path) if path != output_path && File.exist?(path)
  path = output_path
end

DiscourseImage.resize(input: path, output: path, width: 1200, allow_upscale: false)

DiscourseImage.optimize!(path, allow_lossy: true)

size = File.size(path)
puts "Done! Final size: #{(size / 1024.0).round(1)}KB"
