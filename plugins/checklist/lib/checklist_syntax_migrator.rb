# frozen_string_literal: true

class ChecklistSyntaxMigrator
  CHECKBOX_REGEX = /^( {0,3})\[(_|-|\*|\\\*)\]/
  CODE_BLOCK_REGEX = /^ {0,3}```/
  QUOTE_START_REGEX = /^ {0,3}\[quote/
  QUOTE_END_REGEX = /^ {0,3}\[\/quote\]/

  def initialize(post)
    @post = post
  end

  def update_syntax!
    lines = @post.raw.split("\n")
    in_code = false
    in_quote = false
    lines.each_with_index do |line, index|
      if line.match(CODE_BLOCK_REGEX)
        in_code = !in_code
      elsif line.match(QUOTE_START_REGEX)
        in_quote = true
      elsif line.match(QUOTE_END_REGEX)
        in_quote = false
      else
        next if in_code || in_quote

        lines[index] = line.gsub(CHECKBOX_REGEX) { "#{$1}[x]" }
      end
    end
    new_raw = lines.join("\n")

    return if new_raw == @post.raw
    @post.raw = new_raw
    @post.save!
  end
end
