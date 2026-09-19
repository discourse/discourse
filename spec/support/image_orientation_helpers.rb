# frozen_string_literal: true

require "chunky_png"

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

    Dir.mktmpdir do |directory|
      png_path = File.join(directory, "stored.png")
      ImageMagick.magick(
        stored_path,
        png_path,
        operation: :upload_format_conversion,
        read: [stored_path],
        write: [directory],
      )
      stored_image = ChunkyPNG::Image.from_file(png_path)

      Array.new(rows) do |row_index|
        Array.new(columns) do |column_index|
          x = (column_index * stored_image.width + stored_image.width / 2) / columns
          y = (row_index * stored_image.height + stored_image.height / 2) / rows

          nearest_palette_color(pixel: stored_image[x, y], palette: palette)
        end
      end
    end
  end

  def nearest_palette_color(pixel:, palette:)
    actual_rgb = [ChunkyPNG::Color.r(pixel), ChunkyPNG::Color.g(pixel), ChunkyPNG::Color.b(pixel)]

    palette
      .min_by do |_name, expected_rgb|
        expected_rgb
          .zip(actual_rgb)
          .sum { |expected_channel, actual_channel| (expected_channel - actual_channel)**2 }
      end
      .first
  end
end
