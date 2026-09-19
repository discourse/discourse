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
end
