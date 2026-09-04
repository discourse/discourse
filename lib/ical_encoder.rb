# frozen_string_literal: true

module IcalEncoder
  SANITIZER = Rails::Html::FullSanitizer.new

  class << self
    # Encodes a string for use in iCalendar text fields (SUMMARY, DESCRIPTION, LOCATION).
    # Strips HTML tags, decodes HTML entities, and escapes special characters per RFC 5545.
    def encode(text)
      return "" if text.blank?
      text = SANITIZER.sanitize(text)
      text = CGI.unescapeHTML(text)
      text
        .gsub("\\", "\\\\\\\\")
        .gsub(",", "\\,")
        .gsub(";", "\\;")
        .gsub("\r\n", "\\n")
        .gsub("\n", "\\n")
        .html_safe
    end

    # Encodes a URI for iCalendar URL properties (RFC 5545 §3.8.4.6).
    # URL values are URIs per RFC 3986, so comma and semicolon (valid sub-delimiters)
    # must not be TEXT-escaped. Entities are decoded first, then CR/LF stripped —
    # order matters: stripping CR/LF after decoding neutralizes entity-encoded
    # newlines (e.g. `&#13;&#10;`) that would otherwise inject additional ICS
    # properties on the following line.
    def encode_uri(uri)
      return "" if uri.blank?

      CGI.unescapeHTML(uri.to_s).delete("\r\n").html_safe
    end
  end
end
