# frozen_string_literal: true

require "tempfile"
require "zlib"

class Vips
  PNG_FILE_SIGNATURE = "\x89PNG\r\n\x1A\n".b
  MAX_PNG_CHUNKS = 10_000
  MAX_PNG_METADATA_BYTES = 4 * 1024 * 1024
  XMP_JPEG_PREFIX = "http://ns.adobe.com/xap/1.0/\0".b
  PHOTOSHOP_JPEG_PREFIX = "Photoshop 3.0\0".b
  JPEG_EXIF_PREFIX = "Exif\0\0".b
  MAX_JPEG_SEGMENT_BYTES = 65_533

  def self.preserve_png_metadata(source:, output:)
    metadata = png_metadata(source)
    rewrite_jpeg_metadata(output, metadata)
  end
  private_class_method :preserve_png_metadata

  def self.png_metadata(path)
    metadata = { exif: false, xmp: nil, iptc: nil, comments: [] }
    budget = { remaining: MAX_PNG_METADATA_BYTES }

    File.open(path, "rb") do |file|
      if file.read(PNG_FILE_SIGNATURE.bytesize) != PNG_FILE_SIGNATURE
        raise_metadata_error("invalid PNG signature")
      end

      MAX_PNG_CHUNKS.times do
        length_bytes = file.read(4)
        if length_bytes.nil? || length_bytes.bytesize != 4
          raise_metadata_error("truncated PNG chunk length")
        end

        length = length_bytes.unpack1("N")
        type = file.read(4)
        raise_metadata_error("truncated PNG chunk type") if type.nil? || type.bytesize != 4

        data =
          if %w[eXIf tEXt zTXt iTXt].include?(type)
            consume_metadata_budget!(budget, length)
            read_exact(file, length, "PNG metadata chunk")
          else
            file.seek(length, IO::SEEK_CUR)
            nil
          end
        read_exact(file, 4, "PNG chunk checksum")

        metadata[:exif] = true if type == "eXIf"
        capture_png_text_metadata(metadata, type, data, budget) if data && type != "eXIf"
        return metadata if type == "IEND"
      end
    end

    raise_metadata_error("PNG has too many chunks")
  rescue Errno::EINVAL
    raise_metadata_error("invalid PNG chunk length")
  end
  private_class_method :png_metadata

  def self.capture_png_text_metadata(metadata, type, data, budget)
    keyword, text = png_text(type, data, budget)
    return if keyword.nil?

    if keyword == "XML:com.adobe.xmp" && type == "iTXt"
      metadata[:xmp] = text
    elsif keyword.casecmp?("comment")
      metadata[:comments] = [text]
    elsif (profile_type = keyword[/\ARaw profile type (xmp|iptc)\z/i, 1])
      profile = decode_png_raw_profile(text, profile_type, budget)
      metadata[profile_type.downcase.to_sym] = profile
    end
  end
  private_class_method :capture_png_text_metadata

  def self.png_text(type, data, budget)
    case type
    when "tEXt"
      keyword, text = data.split("\0", 2)
      consume_metadata_budget!(budget, text.bytesize) if text
      [keyword, text]
    when "zTXt"
      keyword, compressed = data.split("\0", 2)
      return if compressed.nil? || compressed.getbyte(0) != 0
      [keyword, inflate_bounded(compressed.byteslice(1..), budget)]
    when "iTXt"
      keyword, remainder = data.split("\0", 2)
      return if remainder.nil? || remainder.bytesize < 4

      compression_flag = remainder.getbyte(0)
      compression_method = remainder.getbyte(1)
      language_end = remainder.index("\0", 2)
      return if language_end.nil?
      translated_end = remainder.index("\0", language_end + 1)
      return if translated_end.nil?

      text = remainder.byteslice((translated_end + 1)..)
      return if compression_flag == 1 && compression_method != 0
      if compression_flag == 1
        text = inflate_bounded(text, budget)
      else
        consume_metadata_budget!(budget, text.bytesize)
      end
      [keyword, text]
    end
  rescue Zlib::Error
    raise_metadata_error("invalid compressed PNG metadata")
  end
  private_class_method :png_text

  def self.inflate_bounded(compressed, budget)
    inflater = Zlib::Inflate.new
    output = +"".b
    offset = 0

    while offset < compressed.bytesize
      append_bounded(output, inflater.inflate(compressed.byteslice(offset, 256)), budget)
      offset += 256
    end
    append_bounded(output, inflater.finish, budget)
    output
  ensure
    inflater&.close
  end
  private_class_method :inflate_bounded

  def self.append_bounded(output, value, budget)
    consume_metadata_budget!(budget, value.bytesize)
    output << value
  end
  private_class_method :append_bounded

  def self.decode_png_raw_profile(text, expected_type, budget)
    match = text.match(/\A\s*([a-z0-9]+)\s+(\d+)\s+([0-9a-f\s]+)\z/i)
    if match.nil? || !match[1].casecmp?(expected_type)
      raise_metadata_error("invalid PNG raw profile")
    end

    length_token = match[2]
    if length_token.length > MAX_PNG_METADATA_BYTES.to_s.length
      raise_metadata_error("invalid PNG raw profile length")
    end

    expected_length = length_token.to_i
    raise_metadata_error("oversized PNG raw profile") if expected_length > MAX_PNG_METADATA_BYTES

    hex = match[3].delete(" \t\r\n")
    raise_metadata_error("invalid PNG raw profile length") if hex.bytesize != expected_length * 2

    consume_metadata_budget!(budget, expected_length)
    [hex].pack("H*")
  end
  private_class_method :decode_png_raw_profile

  def self.consume_metadata_budget!(budget, bytes)
    budget[:remaining] -= bytes
    raise_metadata_error("PNG metadata limit exceeded") if budget[:remaining].negative?
  end
  private_class_method :consume_metadata_budget!

  def self.rewrite_jpeg_metadata(path, metadata)
    mode = File.stat(path).mode

    Tempfile.create(%w[vips-metadata .jpg], File.dirname(path)) do |temporary|
      temporary.binmode

      File.open(path, "rb") do |source|
        if read_exact(source, 2, "JPEG signature") != "\xFF\xD8".b
          raise_metadata_error("invalid JPEG signature")
        end
        temporary.write("\xFF\xD8".b)
        write_png_metadata_segments(temporary, metadata)
        copy_jpeg_segments(source, temporary, keep_exif: metadata[:exif])
      end

      temporary.flush
      temporary.close
      File.chmod(mode & 0o777, temporary.path)
      File.rename(temporary.path, path)
    end
  end
  private_class_method :rewrite_jpeg_metadata

  def self.write_png_metadata_segments(output, metadata)
    write_jpeg_segment(output, 0xE1, XMP_JPEG_PREFIX + metadata[:xmp]) if metadata[:xmp]

    if metadata[:iptc]
      resource =
        "8BIM".b + [0x0404].pack("n") + "\0\0".b + [metadata[:iptc].bytesize].pack("N") +
          metadata[:iptc]
      resource << "\0".b if metadata[:iptc].bytesize.odd?
      write_jpeg_segment(output, 0xED, PHOTOSHOP_JPEG_PREFIX + resource)
    end

    metadata[:comments].each { |comment| write_jpeg_segment(output, 0xFE, comment) }
  end
  private_class_method :write_png_metadata_segments

  def self.copy_jpeg_segments(source, output, keep_exif:)
    loop do
      marker_prefix = read_exact(source, 1, "JPEG marker")
      raise_metadata_error("invalid JPEG marker") if marker_prefix.getbyte(0) != 0xFF

      marker = read_exact(source, 1, "JPEG marker").getbyte(0)
      marker = read_exact(source, 1, "JPEG marker").getbyte(0) while marker == 0xFF

      if marker == 0xD9
        output.write([0xFF, marker].pack("C*"))
        return
      end

      if marker == 0xDA
        output.write([0xFF, marker].pack("C*"))
        IO.copy_stream(source, output)
        return
      end

      if marker == 0x01 || marker.between?(0xD0, 0xD7)
        output.write([0xFF, marker].pack("C*"))
        next
      end

      length_bytes = read_exact(source, 2, "JPEG segment length")
      length = length_bytes.unpack1("n")
      raise_metadata_error("invalid JPEG segment length") if length < 2

      payload = read_exact(source, length - 2, "JPEG segment")
      next if discard_jpeg_segment?(marker, payload, keep_exif:)

      output.write([0xFF, marker].pack("C*"))
      output.write(length_bytes)
      output.write(payload)
    end
  end
  private_class_method :copy_jpeg_segments

  def self.discard_jpeg_segment?(marker, payload, keep_exif:)
    return true if marker == 0xFE
    return true if marker == 0xED && payload.start_with?(PHOTOSHOP_JPEG_PREFIX)
    return false if marker != 0xE1
    return true if payload.start_with?(XMP_JPEG_PREFIX)
    !keep_exif && payload.start_with?(JPEG_EXIF_PREFIX)
  end
  private_class_method :discard_jpeg_segment?

  def self.write_jpeg_segment(output, marker, payload)
    if payload.bytesize > MAX_JPEG_SEGMENT_BYTES
      raise_metadata_error("oversized JPEG metadata segment")
    end

    output.write([0xFF, marker, payload.bytesize + 2].pack("CCn"))
    output.write(payload)
  end
  private_class_method :write_jpeg_segment

  def self.read_exact(file, length, label)
    value = file.read(length)
    raise_metadata_error("truncated #{label}") if value.nil? || value.bytesize != length
    value
  end
  private_class_method :read_exact

  def self.raise_metadata_error(message)
    raise Discourse::Utils::CommandError, message
  end
  private_class_method :raise_metadata_error

  private_constant :JPEG_EXIF_PREFIX,
                   :MAX_JPEG_SEGMENT_BYTES,
                   :MAX_PNG_CHUNKS,
                   :MAX_PNG_METADATA_BYTES,
                   :PHOTOSHOP_JPEG_PREFIX,
                   :PNG_FILE_SIGNATURE,
                   :XMP_JPEG_PREFIX
end
