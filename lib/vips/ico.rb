# frozen_string_literal: true

require "zlib"

class Vips
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
  MAX_FILE_SIZE = 100.megabytes

  def self.ico_to_png(path:, output:)
    data = File.binread(path, MAX_FILE_SIZE + 1)
    raise Discourse::InvalidAccess if data.bytesize > MAX_FILE_SIZE || data.bytesize < 22

    reserved, type, count = data.byteslice(0, 6).unpack("v3")
    raise Discourse::InvalidAccess if reserved != 0 || type != 1 || count.zero?

    directory_size = 6 + (count * 16)
    raise Discourse::InvalidAccess if directory_size > data.bytesize

    entry = parse_entry(data.byteslice(6 + ((count - 1) * 16), 16))
    finish = entry[:offset] + entry[:size]
    raise Discourse::InvalidAccess if entry[:offset] < directory_size || finish > data.bytesize

    image = data.byteslice(entry[:offset], entry[:size])
    png = image.start_with?(PNG_SIGNATURE) ? image : dib_to_png(data: image, entry:)
    File.binwrite(output, png)
  end

  def self.parse_entry(bytes)
    width, height, colors, reserved, planes, bits, size, offset = bytes.unpack("C4v2V2")
    raise Discourse::InvalidAccess if reserved != 0 || size.zero?

    {
      width: width.zero? ? 256 : width,
      height: height.zero? ? 256 : height,
      colors:,
      planes:,
      bits:,
      size:,
      offset:,
    }
  end
  private_class_method :parse_entry

  def self.dib_to_png(data:, entry:)
    header = dib_header(data)
    width = header[:width]
    height = header[:height]
    raise Discourse::InvalidAccess if width != entry[:width] || height != entry[:height]
    raise Discourse::InvalidAccess if width <= 0 || height <= 0 || width > 256 || height > 256

    palette, pixel_offset = palette(data:, header:, entry:)
    row_size = ((width * header[:bits] + 31) / 32) * 4
    pixel_size = row_size * height
    raise Discourse::InvalidAccess if pixel_offset + pixel_size > data.bytesize

    pixels = String.new(capacity: width * height * 4, encoding: Encoding::BINARY)
    alpha_present = false

    height.times do |y|
      source_y = header[:top_down] ? y : height - y - 1
      row = data.byteslice(pixel_offset + (source_y * row_size), row_size)
      width.times do |x|
        red, green, blue, alpha = pixel(row:, x:, header:, palette:)
        alpha_present ||= alpha.positive? if header[:bits] == 32
        pixels << red << green << blue << alpha
      end
    end

    if header[:bits] == 32 && !alpha_present
      (3...pixels.bytesize).step(4) { |index| pixels.setbyte(index, 255) }
    end

    apply_mask(data:, pixels:, width:, height:, offset: pixel_offset + pixel_size)
    encode_png(width:, height:, pixels:)
  end
  private_class_method :dib_to_png

  def self.dib_header(data)
    raise Discourse::InvalidAccess if data.bytesize < 12
    size = data.unpack1("V")

    if size == 12
      width, total_height, planes, bits = data.byteslice(4, 8).unpack("v4")
      {
        size:,
        width:,
        height: total_height / 2,
        top_down: false,
        planes:,
        bits:,
        compression: 0,
        colors: 0,
        palette_entry_size: 3,
        masks: nil,
        data_offset: 12,
      }
    else
      raise Discourse::InvalidAccess if size < 40 || size > data.bytesize
      width, total_height = data.byteslice(4, 8).unpack("l<2")
      planes, bits = data.byteslice(12, 4).unpack("v2")
      compression = data.byteslice(16, 4).unpack1("V")
      colors = data.byteslice(32, 4).unpack1("V")
      masks, data_offset = masks(data:, header_size: size, compression:)

      {
        size:,
        width: width.abs,
        height: total_height.abs / 2,
        top_down: total_height.negative?,
        planes:,
        bits:,
        compression:,
        colors:,
        palette_entry_size: 4,
        masks:,
        data_offset:,
      }
    end.tap do |header|
      raise Discourse::InvalidAccess if header[:planes] != 1
      raise Discourse::InvalidAccess if ![1, 4, 8, 16, 24, 32].include?(header[:bits])
      raise Discourse::InvalidAccess if ![0, 3, 6].include?(header[:compression])
    end
  end
  private_class_method :dib_header

  def self.masks(data:, header_size:, compression:)
    return nil, header_size if ![3, 6].include?(compression)

    if header_size >= 52
      count = header_size >= 56 ? 4 : 3
      [data.byteslice(40, count * 4).unpack("V#{count}"), header_size]
    else
      count = compression == 6 ? 4 : 3
      length = count * 4
      raise Discourse::InvalidAccess if header_size + length > data.bytesize
      [data.byteslice(header_size, length).unpack("V#{count}"), header_size + length]
    end
  end
  private_class_method :masks

  def self.palette(data:, header:, entry:)
    count =
      if header[:bits] <= 8
        if header[:colors].positive?
          header[:colors]
        else
          (entry[:colors].positive? ? entry[:colors] : 1 << header[:bits])
        end
      else
        0
      end
    length = count * header[:palette_entry_size]
    offset = header[:data_offset]
    raise Discourse::InvalidAccess if offset + length > data.bytesize

    colors =
      count.times.map do |index|
        bytes =
          data.byteslice(
            offset + (index * header[:palette_entry_size]),
            header[:palette_entry_size],
          )
        [bytes.getbyte(2), bytes.getbyte(1), bytes.getbyte(0), 255]
      end
    [colors, offset + length]
  end
  private_class_method :palette

  def self.pixel(row:, x:, header:, palette:)
    case header[:bits]
    when 1
      palette.fetch((row.getbyte(x / 8) >> (7 - (x % 8))) & 1)
    when 4
      byte = row.getbyte(x / 2)
      palette.fetch(x.even? ? byte >> 4 : byte & 0x0F)
    when 8
      palette.fetch(row.getbyte(x))
    when 16
      value = row.byteslice(x * 2, 2).unpack1("v")
      masks = header[:masks] || [0x7C00, 0x03E0, 0x001F]
      [
        mask_component(value:, mask: masks[0]),
        mask_component(value:, mask: masks[1]),
        mask_component(value:, mask: masks[2]),
        masks[3] ? mask_component(value:, mask: masks[3]) : 255,
      ]
    when 24
      blue, green, red = row.byteslice(x * 3, 3).unpack("C3")
      [red, green, blue, 255]
    when 32
      value = row.byteslice(x * 4, 4).unpack1("V")
      if header[:masks]
        [
          mask_component(value:, mask: header[:masks][0]),
          mask_component(value:, mask: header[:masks][1]),
          mask_component(value:, mask: header[:masks][2]),
          header[:masks][3] ? mask_component(value:, mask: header[:masks][3]) : 255,
        ]
      else
        blue, green, red, alpha = row.byteslice(x * 4, 4).unpack("C4")
        [red, green, blue, alpha]
      end
    end
  end
  private_class_method :pixel

  def self.mask_component(value:, mask:)
    return 0 if mask.nil? || mask.zero?
    shift = 0
    shifted = mask
    while (shifted & 1).zero?
      shifted >>= 1
      shift += 1
    end
    (((value & mask) >> shift) * 255.0 / shifted).round
  end
  private_class_method :mask_component

  def self.apply_mask(data:, pixels:, width:, height:, offset:)
    row_size = ((width + 31) / 32) * 4
    return if offset + (row_size * height) > data.bytesize

    height.times do |y|
      source_y = height - y - 1
      row = data.byteslice(offset + (source_y * row_size), row_size)
      width.times do |x|
        next if ((row.getbyte(x / 8) >> (7 - (x % 8))) & 1).zero?
        pixels.setbyte(((y * width + x) * 4) + 3, 0)
      end
    end
  end
  private_class_method :apply_mask

  def self.encode_png(width:, height:, pixels:)
    rows = String.new(capacity: pixels.bytesize + height, encoding: Encoding::BINARY)
    stride = width * 4
    height.times { |y| rows << 0 << pixels.byteslice(y * stride, stride) }

    PNG_SIGNATURE + png_chunk(type: "IHDR", payload: [width, height, 8, 6, 0, 0, 0].pack("NNC5")) +
      png_chunk(type: "IDAT", payload: Zlib::Deflate.deflate(rows, Zlib::BEST_COMPRESSION)) +
      png_chunk(type: "IEND", payload: "".b)
  end
  private_class_method :encode_png

  def self.png_chunk(type:, payload:)
    type = type.b
    [payload.bytesize].pack("N") + type + payload + [Zlib.crc32(type + payload)].pack("N")
  end
  private_class_method :png_chunk

  private_constant :PNG_SIGNATURE, :MAX_FILE_SIZE
end
