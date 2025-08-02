# frozen_string_literal: true

module XmlCleaner
  INVALID_CHARACTERS = /[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD\u{10000}-\u{10FFFF}]/u
end
