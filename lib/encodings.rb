# frozen_string_literal: true

require 'rchardet'

module Encodings
  def self.to_utf8(string)
    result = CharDet.detect(string)

    encoded_string = try_utf8(string, result['encoding']) if result && result['encoding']
    encoded_string = force_utf8(string) if encoded_string.nil?
    encoded_string
  end

  def self.try_utf8(string, source_encoding)
    encoded = string.encode(Encoding::UTF_8, source_encoding)
    encoded&.valid_encoding? ? delete_bom!(encoded) : nil
  rescue Encoding::InvalidByteSequenceError,
    Encoding::UndefinedConversionError,
    Encoding::ConverterNotFoundError
    nil
  end

  def self.force_utf8(string)
    encoded_string = string.encode(Encoding::UTF_8,
                                   undef: :replace,
                                   invalid: :replace,
                                   replace: '')
    delete_bom!(encoded_string)
  end

  def self.delete_bom!(string)
    string.sub!(/\A\xEF\xBB\xBF/, '') unless string.blank?
    string
  end
end
