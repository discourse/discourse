# frozen_string_literal: true

module IcalEncoder
  SANITIZER = Rails::Html::FullSanitizer.new

  # Encodes a string for use in iCalendar text fields (SUMMARY, DESCRIPTION, LOCATION).
  # Strips HTML tags, decodes HTML entities, and escapes special characters per RFC 5545.
  def self.encode(text)
    return "" if text.blank?
    text = SANITIZER.sanitize(text)
    text = CGI.unescapeHTML(text)
    text
      .gsub("\\", "\\\\\\\\")
      .gsub(",", "\\,")
      .gsub(";", "\\;")
      .gsub("\r\n", "\\n")
      .gsub("\n", "\\n")
  end
end
