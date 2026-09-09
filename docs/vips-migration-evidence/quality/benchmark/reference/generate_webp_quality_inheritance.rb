# frozen_string_literal: true

require "vips"
require "json"
require "digest"
require "fileutils"

module WebpQualityInheritanceFixtures
  WIDTH = 3072
  HEIGHT = 8

  def self.chunk(type:, payload:)
    type.b + [payload.bytesize].pack("V") + payload + (payload.bytesize.odd? ? "\0".b : "".b)
  end

  def self.uint24(value)
    [value].pack("V").byteslice(0, 3)
  end

  def self.fragment(encoded)
    raise "encoder did not produce RIFF WebP" unless encoded.byteslice(0, 4) == "RIFF" && encoded.byteslice(8, 4) == "WEBP"

    offset = 12
    while offset + 8 <= encoded.bytesize
      type = encoded.byteslice(offset, 4)
      length = encoded.byteslice(offset + 4, 4).unpack1("V")
      ending = offset + 8 + length + length % 2
      raise "truncated encoded chunk" if ending > encoded.bytesize
      return encoded.byteslice(offset, ending - offset) if type == "VP8 "

      offset = ending
    end
    raise "lossy encoder did not produce VP8"
  end

  def self.animation(fragments)
    flags = [2, 0, 0, 0].pack("C*")
    payload = chunk(type: "VP8X", payload: flags + uint24(WIDTH - 1) + uint24(HEIGHT - 1))
    payload += chunk(type: "ANIM", payload: [0, 0].pack("Vv"))
    fragments.each do |bytes|
      frame_header = uint24(0) + uint24(0) + uint24(WIDTH - 1) + uint24(HEIGHT - 1) + uint24(100) + [2].pack("C")
      payload += chunk(type: "ANMF", payload: frame_header + bytes)
    end
    "RIFF".b + [payload.bytesize + 4].pack("V") + "WEBP".b + payload
  end

  private_class_method :chunk, :uint24, :fragment, :animation

  def self.generate(output_directory)
    Vips.cache_set_max(0)
    Vips.concurrency_set(1)
    image = Vips::Image.black(WIDTH, HEIGHT).new_from_image([70, 130, 210]).cast(:uchar).copy(interpretation: :srgb)
    encoded = image.webpsave_buffer(Q: 75, lossless: false, effort: 0, strip: true)
    ordinary = fragment(encoded)
    width_word = ordinary.byteslice(14, 2).unpack1("v")
    raise "unexpected encoded VP8 width or scaling" unless width_word == WIDTH
    raise "unexpected ordinary marker" unless ordinary.getbyte(15) == 0x0c

    classified = ordinary.dup
    classified[14, 2] = [width_word | 0x4000].pack("v")
    raise "expected fragment byte15 L" unless classified.getbyte(15) == "L".ord
    selected = { "classified_100" => classified, "ordinary_92" => ordinary }.transform_values do |bytes|
      static = "RIFF".b + [bytes.bytesize + 4].pack("V") + "WEBP".b + bytes
      { bytes: bytes, static: static, marker: bytes.getbyte(15) }
    end
    reference = Vips::Image.webpload_buffer(selected.fetch("ordinary_92").fetch(:static))
    alternate = Vips::Image.webpload_buffer(selected.fetch("classified_100").fetch(:static))
    [reference, alternate].each do |decoded|
      raise "VP8 scale flag changed decoded dimensions" unless decoded.width == WIDTH && decoded.height == HEIGHT
    end
    raise "VP8 scale flag changed decoded pixels" unless reference.write_to_memory == alternate.write_to_memory

    FileUtils.mkdir_p(output_directory)
    manifest = {
      generator_sha256: Digest::SHA256.file(__FILE__).hexdigest,
      libvips: Vips.version_string,
      dimensions: [WIDTH, HEIGHT],
      source_recipe: "3072x8 constantRGB70,130,210; libvips lossyWebP Q75 effort0 striptrue; set only the VP8 width-word horizontal scaling field from0 to1 (5/4), preserving lower14-bit width3072 and all compressed pixels",
      format_reference: "https://www.rfc-editor.org/rfc/rfc6386.html#section-9.1",
      decoder_reference: "https://github.com/webmproject/libwebp/blob/main/src/dec/vp8_dec.c",
      baseline_fragment_marker: 12,
      changed_fragment_marker: 76,
      native_static_pixels_identical: true,
      expectation_scope: "ImageMagick7.1.2-27 fragment-offset15 classification and first-frame quality inheritance, not true lossless detection",
      fragments: {},
      cases: [],
    }
    selected.each do |label, data|
      static_path = File.join(output_directory, "#{label}-static.webp")
      File.binwrite(static_path, data.fetch(:static))
      Vips::Image.webpload(static_path).write_to_memory
      manifest[:fragments][label] = {
        fragment_byte_15: data.fetch(:marker),
        fragment_sha256: Digest::SHA256.hexdigest(data.fetch(:bytes)),
        static_filename: File.basename(static_path),
        static_sha256: Digest::SHA256.file(static_path).hexdigest,
      }
    end
    cases = {
      "first-100-then-ordinary" => { labels: %w[classified_100 ordinary_92], qualities: [100, 100] },
      "ordinary-then-100" => { labels: %w[ordinary_92 classified_100], qualities: [92, 100] },
      "later-100-not-sticky" => { labels: %w[ordinary_92 classified_100 ordinary_92], qualities: [92, 100, 92] },
      "ordinary-control" => { labels: %w[ordinary_92 ordinary_92], qualities: [92, 92] },
    }
    cases.each do |name, example|
      encoded = animation(example.fetch(:labels).map { |label| selected.fetch(label).fetch(:bytes) })
      path = File.join(output_directory, "#{name}.webp")
      File.binwrite(path, encoded)
      decoded = Vips::Image.webpload(path, n: -1)
      count = example.fetch(:labels).length
      raise "unexpected frame count for #{name}" unless decoded.get("n-pages") == count
      raise "unexpected dimensions for #{name}" unless decoded.width == WIDTH && decoded.height == HEIGHT * count
      decoded.write_to_memory
      manifest[:cases] << {
        filename: File.basename(path),
        sha256: Digest::SHA256.file(path).hexdigest,
        bytes: encoded.bytesize,
        frame_labels: example.fetch(:labels),
        expected_imagemagick_frame_qualities: example.fetch(:qualities),
        expected_quality_integer: example.fetch(:qualities).join.to_i,
        native_decode_validated: true,
      }
    end
    File.write(File.join(output_directory, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
    puts JSON.pretty_generate(manifest)
  end
end

WebpQualityInheritanceFixtures.generate(ARGV.fetch(0, File.join(__dir__, "webp-quality-inheritance-fixtures")))
