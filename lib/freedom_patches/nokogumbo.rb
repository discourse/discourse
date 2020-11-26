# frozen_string_literal: true

# TODO: Remove once fix is merged and nokogumbo version is bumped
# https://github.com/rubys/nokogumbo/pull/158

module Nokogiri
  module HTML5
    private

    def self.read_and_encode(string, encoding)
      # Read the string with the given encoding.
      if string.respond_to?(:read)
        if encoding.nil?
          string = string.read
        else
          string = string.read(encoding: encoding)
        end
      else
        # Otherwise the string has the given encoding.
        string = string.to_s
        if encoding
          string = string.dup
          string.force_encoding(encoding)
        end
      end

      # convert to UTF-8
      if string.encoding != Encoding::UTF_8
        string = reencode(string)
      end
      string
    end
  end
end
