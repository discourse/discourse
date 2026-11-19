# frozen_string_literal: true

require "vips"

module ImageOrientationHelpers
  private

  def with_jpeg_orientation(source_path:, orientation:)
    exif =
      "Exif\0\0".b + "II*\0".b + [8].pack("V") + [1].pack("v") + [0x0112].pack("v") +
        [3].pack("v") + [1].pack("V") + [orientation].pack("v") + "\0\0".b + [0].pack("V")
    marker = "\xFF\xE1".b + [exif.bytesize + 2].pack("n") + exif
    source = File.binread(source_path)
    oriented_file = Tempfile.new(["oriented-#{orientation}", ".jpg"])
    oriented_file.binmode
    oriented_file.write(source.byteslice(0, 2) + marker + source.byteslice(2..))
    oriented_file.rewind

    yield oriented_file
  ensure
    oriented_file&.close!
  end

  def stored_color_grid(upload:, rows:, columns:, palette:)
    stored_path = Discourse.store.path_for(upload)

    image = Vips::Image.jpegload(stored_path)
    Array.new(rows) do |row_index|
      Array.new(columns) do |column_index|
        x = (column_index * image.width + image.width / 2) / columns
        y = (row_index * image.height + image.height / 2) / rows
        nearest_palette_color(actual_rgb: image.getpoint(x, y), palette:)
      end
    end
  end

  def nearest_palette_color(actual_rgb:, palette:)
    palette
      .min_by do |_name, expected_rgb|
        expected_rgb
          .zip(actual_rgb)
          .sum { |expected_channel, actual_channel| (expected_channel - actual_channel)**2 }
      end
      .first
  end
end
