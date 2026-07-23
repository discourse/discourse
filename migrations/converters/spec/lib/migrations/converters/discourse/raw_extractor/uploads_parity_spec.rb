# frozen_string_literal: true

# Cross-checks the full-URL upload detector's bare-URL boundary against what core
# renders. It shares {Base#bare_url_boundary_before?} with the internal-link
# detector, so it rides the same linkify boundary (see
# `internal_links_parity_spec.rb`); this smaller battery confirms an upload URL —
# recognized by its 40-hex sha1, not by a route — admits at the same characters.
# For every boundary character we build `a<char><upload-url> b` (and the forward
# variant) and assert the detector defers exactly when `PrettyText.cook` linkifies
# an anchor for the URL. Needs a booted Rails environment, so it is tagged `:rails`
# and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  before { SiteSetting.enable_markdown_linkify = true }

  def url
    sha1 = "0123456789abcdef0123456789abcdef01234567"
    "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
  end

  # The same representative set as the internal-link battery: ASCII punctuation
  # plus letters, whitespace, and the Unicode characters that split core's linkify
  # boundary from a plain "not a word character" one.
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
      "superscript two" => "²",
      "vulgar half" => "½",
      "soft hyphen" => "­",
    }.merge(ascii_punctuation)
  end

  def detector_extracts?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(embeds: buffer).extract(raw)
    buffer.uploads.any?
  end

  def core_links?(raw)
    hrefs = PrettyText.cook(raw).scan(/<a\b[^>]*href="([^"]*)"/).flatten
    hrefs.any? { |href| href.start_with?(url) }
  end

  def describe_char(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end

  def deviations_for(direction)
    boundary_chars.filter_map do |label, char|
      raw = direction == :before ? "a#{char}#{url} b" : "a #{url}#{char} b"
      extracted = detector_extracts?(raw)
      linkified = core_links?(raw)
      next if extracted == linkified

      "#{direction} #{label} #{describe_char(char)}: detector=#{extracted} core=#{linkified}"
    end
  end

  it "defers exactly when core linkifies, for every character before the URL" do
    deviations = deviations_for(:before)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  # The sha1 sits mid-URL, so a trailing character never disturbs recognition and
  # the `\w` tail trims the same trailing punctuation linkify does — both sides
  # keep the URL and drop what follows, so the whole set is parity.
  it "defers exactly when core linkifies, for every character after the URL" do
    deviations = deviations_for(:forward)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "defers at the very start of the input, matching core" do
    raw = "#{url} b"
    expect(detector_extracts?(raw)).to eq(core_links?(raw))
  end
end
