# frozen_string_literal: true

# Cross-checks the hashtag detector against what core actually renders. For every
# boundary character in a representative set we build `a<char>#general x` (and the
# forward variant `a #general<char> x`) and assert the detector extracts exactly
# when `PrettyText.cook` produces a cooked hashtag link. This needs a booted Rails
# environment (PrettyText's server-side markdown-it and a real category to look
# up), so it is tagged `:rails` and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  # The category the battery looks up. A hashtag whose name resolves to a real
  # category is what core cooks into a `hashtag-cooked` link.
  let!(:category) do
    Category.find_by(slug: "general") ||
      Fabricate(:category, name: "General parity", slug: "general")
  end
  let!(:user) { Fabricate(:user) }

  # Extraction is gated on the source's names, so the detector defers only a
  # hashtag that names something real — the same condition under which core cooks.
  let(:hashtag_names) do
    Migrations::SortedStringSet.new([Migrations::NameNormalizer.normalize("general")])
  end

  # The 32 ASCII punctuation characters (CommonMark), which already include the
  # ASCII symbols `$ + < = > ^ \` | ~`, plus the letters, whitespace, and Unicode
  # punctuation/symbol characters that exercise the boundary from both sides.
  def boundary_chars
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
      "no-break space" => " ",
      "ideographic space" => "　",
      "em dash" => "—",
      "low double quote" => "„",
      "left guillemet" => "«",
      "ellipsis" => "…",
      "euro sign" => "€",
    }.merge(ascii_punctuation)
  end

  # Cases where the detector intentionally differs from core, keyed by
  # "direction char". A lone backtick before the `#` is the one: our scanner treats
  # an unpaired backtick as opening an inline-code span (conservative, so it never
  # extracts from inside code) and skips the rest of the line, while core treats
  # the backtick as literal and cooks the hashtag after it. That is a scanner-wide
  # inline-code behavior, not part of the hashtag boundary.
  def allowed_divergence?(direction, char)
    direction == :before && char == "`"
  end

  def detector_extracts?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(embeds: buffer, hashtag_names:).extract(raw)
    buffer.hashtags.any?
  end

  def core_cooks?(raw)
    PrettyText.cook(raw, user_id: user.id).include?("hashtag-cooked")
  end

  def describe_char(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end

  def deviations_for(direction)
    boundary_chars.filter_map do |label, char|
      raw = direction == :before ? "a#{char}#general x" : "a #general#{char} x"
      extracted = detector_extracts?(raw)
      cooked = core_cooks?(raw)
      next if extracted == cooked
      next if allowed_divergence?(direction, char)

      "#{direction} #{label} #{describe_char(char)}: detector=#{extracted} core=#{cooked}"
    end
  end

  it "extracts exactly when core cooks, for every character before the hash" do
    deviations = deviations_for(:before)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "extracts exactly when core cooks, for every character after the name" do
    deviations = deviations_for(:forward)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "extracts a hashtag at the very start of the input, matching core" do
    raw = "#general x"
    expect(detector_extracts?(raw)).to eq(core_cooks?(raw))
  end
end
