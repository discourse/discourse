# frozen_string_literal: true

# fix_zero_width_spaces.rb
# There are 5 kinds of zero-width characters that might appear in the raw text of a post.
# They're frequently included accidentally when users copy/paste from the web or from documents.
# The five we target are:
#  * Zero-width space (U+200B) - used to suggest a line-break opportunity, not an actual space
#  * Zero-width non-joiner (U+200C) - prevents ligature formation between adjacent characters
#  * Zero-width joiner (U+200D) - encourages ligature formation
#  * Byte Order Mark (BOM) (U+FEFF) - meant to be at the beginning of a file, but could end up in a post.
#  * Soft hyphen (U+00AD) - invisible unless a line break occurs there
# Strips zero-width Unicode characters from post raw text and rebakes only affected posts.
#
# Usage:
#   bundle exec rails runner script/import_scripts/vbulletin5/fix_zero_width_spaces.rb

ZERO_WIDTH_RE = /[\u200B\u200C\u200D\uFEFF\u00AD]/

# Use a plain Ruby string with the actual Unicode characters for the SQL pattern
ZW_PATTERN = "[\u200B\u200C\u200D\uFEFF\u00AD]"

affected = Post.where("raw ~ ?", ZW_PATTERN)
total    = affected.count
puts "#{total} post(s) affected"

fixed  = 0
errors = 0

affected.find_each do |post|
  new_raw = post.raw.gsub(ZERO_WIDTH_RE, "")
  next if new_raw == post.raw

  post.raw = new_raw
  post.save!(validate: false)
  post.rebake!
  fixed += 1
  print "\r#{fixed}/#{total} fixed"
rescue StandardError => e
  puts "\nERROR post #{post.id}: #{e.message.lines.first&.strip}"
  errors += 1
end

puts "", "Done. #{fixed} fixed, #{errors} errors."
