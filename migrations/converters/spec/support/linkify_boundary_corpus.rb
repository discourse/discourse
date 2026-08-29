# frozen_string_literal: true

# The boundary characters the linkify parity batteries probe, shared so the
# internal-link and upload suites test the same set: the 32 ASCII punctuation
# characters (CommonMark), plus letters, whitespace, and the Unicode
# characters that split core's linkify boundary from a plain "not a word
# character" one — the wide spaces (NBSP, ideographic space), `²`/`½`
# (category No), `€` (a currency symbol, category Sc), and `­` (soft hyphen,
# category Cf).
module LinkifyBoundaryCorpus
  def self.chars
    ascii_punctuation =
      [0x21..0x2f, 0x3a..0x40, 0x5b..0x60, 0x7b..0x7e].flat_map(&:to_a)
        .to_h { |cp| [format("U+%04X", cp), cp.chr(Encoding::UTF_8)] }

    {
      "letter a" => "a",
      "digit 9" => "9",
      "e-acute" => "é",
      "han" => "漢",
      "space" => " ",
      "tab" => "\t",
      "newline" => "\n",
      "no-break space" => "\u00A0",
      "ideographic space" => "\u3000",
      "em dash" => "—",
      "low double quote" => "„",
      "left guillemet" => "«",
      "ellipsis" => "…",
      "euro sign" => "€",
      "superscript two" => "²",
      "vulgar half" => "½",
      "soft hyphen" => "\u00AD",
    }.merge(ascii_punctuation)
  end

  def self.describe(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end
end
