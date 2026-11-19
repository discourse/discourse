# frozen_string_literal: true

# Usage: bin/rails runner ~/path/to/discourse-upcoming-changes/scripts/optimize_upcoming_change_image.rb <path>
#
# Converts (if needed), resizes, and optimizes an image for use as an upcoming change preview.

require "vips"

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

output_path = File.join(File.dirname(path), "#{File.basename(path, ".*")}.png")
image = Vips::Image.thumbnail(path, 1200, size: :down)
ImageProcessing::OutputFile.write(output_path) { |temporary_path| image.pngsave(temporary_path) }

FileHelper.optimize_image!(output_path, allow_pngquant: true)
File.delete(path) unless File.identical?(path, output_path)

size = File.size(output_path)
puts "Done! Final size: #{(size / 1024.0).round(1)}KB"
