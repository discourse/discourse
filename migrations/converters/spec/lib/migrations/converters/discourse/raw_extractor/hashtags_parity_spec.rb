# frozen_string_literal: true

# Cross-checks the hashtag construct against what core actually renders. For every
# boundary character in a representative set we build `a<char>#general x` (and the
# forward variant `a #general<char> x`) and assert the construct extracts exactly
# when `PrettyText.cook` produces a cooked hashtag link. This needs a booted Rails
# environment (PrettyText's server-side markdown-it and a real category to look
# up), so it is tagged `:rails` and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  # This spec is not about mentions; the extractor needs the set anyway.
  def mention_names
    Migrations::CompactStringSet.new([])
  end
  # The category the battery looks up. A hashtag whose name resolves to a real
  # category is what core cooks into a `hashtag-cooked` link.
  let!(:category) do
    Category.find_by(slug: "general") ||
      Fabricate(:category, name: "General parity", slug: "general")
  end
  let!(:user) { Fabricate(:user) }

  # Extraction is gated on the source's names, so the construct defers only a
  # hashtag that names something real — the same condition under which core cooks.
  let(:hashtag_names) do
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("general")])
  end

  let(:markdown_engine) { MarkdownEngineHelper.context_for_names(hashtag_names: %w[general]) }

  # The 32 ASCII punctuation characters (CommonMark), which already include the
  # ASCII symbols `$ + < = > ^ \` | ~`, plus letters, whitespace, and Unicode
  # punctuation/symbol characters that exercise the boundary from both sides. The
  # last three are the telling ones: `²` and `½` are category No and `­` (soft
  # hyphen) is category Cf — none are a word character, a space, or punctuation, so
  # they separate a plain word boundary from core's punctuation-or-space boundary.
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

  def construct_extracts?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:).extract(
      raw,
    )
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
      extracted = construct_extracts?(raw)
      cooked = core_cooks?(raw)
      next if extracted == cooked

      "#{direction} #{label} #{describe_char(char)}: construct=#{extracted} core=#{cooked}"
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
    expect(construct_extracts?(raw)).to eq(core_cooks?(raw))
  end
end
