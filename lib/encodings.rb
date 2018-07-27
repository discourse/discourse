require 'charlock_holmes'

module Encodings
  BINARY_SCAN_LENGTH = 0

  def self.to_utf8(string, encoding_hint: nil, delete_bom: true)
    detector = CharlockHolmes::EncodingDetector.new(BINARY_SCAN_LENGTH)
    result = detector.detect(string, encoding_hint&.to_s)

    if result && result[:encoding]
      string = CharlockHolmes::Converter.convert(string, result[:encoding], Encoding::UTF_8.name)
    else
      string = string.encode(Encoding::UTF_8, undef: :replace, invalid: :replace, replace: '')
    end

    delete_bom!(string) if delete_bom
    string
  end

  def self.try_utf8(string, source_encoding)
    encoded = string.encode(Encoding::UTF_8, source_encoding)
    encoded&.valid_encoding? ? delete_bom!(encoded) : nil
  rescue Encoding::InvalidByteSequenceError,
    Encoding::UndefinedConversionError,
    Encoding::ConverterNotFoundError
    nil
  end

  def self.delete_bom!(string)
    string.sub!(/\A\xEF\xBB\xBF/, '') unless string.blank?
    string
  end
end
