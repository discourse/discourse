# frozen_string_literal: true

module Encodings
  BOM = "\u{FEFF}"

  def self.force_utf8(string)
    encoded_string = string.encode(Encoding::UTF_8, undef: :replace, invalid: :replace, replace: "")
    delete_bom!(encoded_string)
  end

  def self.delete_bom!(string)
    string.presence&.delete_prefix!(BOM)
    string
  end

  # Returns the lowercase charset name declared in an HTTP Content-Type header,
  # or nil when absent or unsupported. HTML parsers like Nokogiri only receive
  # the raw body and cannot see transport-level headers, so callers must pass
  # the extracted charset along explicitly.
  def self.charset_from_content_type(content_type)
    return if content_type.blank?

    charset = content_type[/\bcharset\s*=\s*"?([a-z0-9_-]+)"?/i, 1]
    return if charset.blank?

    encoding = Encoding.find(charset)
    return if encoding.dummy?

    # Ruby has no identity converter, so skip the probe for UTF-8 itself.
    Encoding::Converter.new(encoding, Encoding::UTF_8) if encoding != Encoding::UTF_8

    charset.downcase
  rescue ArgumentError, Encoding::ConverterNotFoundError
    nil
  end

  def self.charset_from_document(html)
    head = html.to_s.byteslice(0, 1024).to_s
    charset = head[/<meta[^>]*\bcharset\s*=\s*["']?([a-z0-9_-]+)/i, 1]
    charset&.downcase
  end

  def self.valid_utf8?(string)
    string.to_s.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  end

  def self.unicode_encoding?(charset)
    encoding = Encoding.find(charset)
    [
      Encoding::UTF_8,
      Encoding::UTF_16LE,
      Encoding::UTF_16BE,
      Encoding::UTF_32LE,
      Encoding::UTF_32BE,
    ].include?(encoding)
  rescue ArgumentError
    false
  end
end
