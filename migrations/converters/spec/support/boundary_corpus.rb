# frozen_string_literal: true

# The boundary characters the construct parity batteries probe, shared so every
# construct is checked against the same set: the 32 ASCII punctuation characters
# (CommonMark), which already include the ASCII symbols `$ + < = > ^ ` | ~`,
# plus letters, whitespace, and the Unicode characters that separate a plain
# "not a word character" boundary from the one core actually applies — the wide
# spaces (NBSP, ideographic space), `²`/`½` (category No), `€` (a currency
# symbol, category Sc), and `­` (soft hyphen, category Cf). The invisible ones
# are written as escapes so they cannot silently regress to a plain space.
module BoundaryCorpus
  # @param zero_width_space [Boolean] include U+200B, which core's emoji rule
  #   accepts as a boundary although it is neither a space it counts nor
  #   punctuation.
  def self.chars(zero_width_space: false)
    ascii_punctuation =
      [0x21..0x2f, 0x3a..0x40, 0x5b..0x60, 0x7b..0x7e].flat_map(&:to_a)
        .to_h { |cp| [format("U+%04X", cp), cp.chr(Encoding::UTF_8)] }

    chars = {
      "letter a" => "a",
      "digit 9" => "9",
      "e-acute" => "é",
      "han" => "漢",
      "space" => " ",
      "tab" => "\t",
      "newline" => "\n",
      "no-break space" => " ",
      "ideographic space" => "　",
      "em dash" => "—",
      "low double quote" => "„",
      "left guillemet" => "«",
      "ellipsis" => "…",
      "euro sign" => "€",
      "superscript two" => "²",
      "vulgar half" => "½",
      "soft hyphen" => "­",
    }
    chars["zero-width space"] = "​" if zero_width_space
    chars.merge(ascii_punctuation)
  end

  def self.describe(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end
end
