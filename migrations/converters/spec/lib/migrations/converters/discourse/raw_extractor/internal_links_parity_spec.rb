# frozen_string_literal: true

# Cross-checks the internal-link detector's bare-URL boundary against what core
# actually renders. For every boundary character in a representative set we build
# `a<char>https://forum.example.com/t/slug/5 b` (and the forward variant with the
# character right after the URL) and assert the detector records a link exactly
# when `PrettyText.cook` linkifies an anchor for that URL.
#
# Core's machinery for a bare absolute URL in prose is markdown-it's linkify, fed
# by two engines whose admissions are unioned: the inline rule
# (`markdown-it/rules_inline/linkify.mjs`, a scheme after anything outside
# `[A-Za-z0-9.+-]`) and the core ruler (`rules_core/linkify.mjs` via linkify-it,
# which also admits `.` and `-`). The net boundary before a scheme is "any
# character except an ASCII letter, digit or `+`" (and `\`, a markdown escape) —
# far wider than the whitespace-or-paren gate the detector used to admit at, so it
# is checked here against PrettyText rather than read off a regex. The URL is
# inline in a sentence, so no onebox block path. Needs a booted Rails environment,
# so it is tagged `:rails` and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  # This spec is about neither mentions nor hashtags; the extractor requires
  # both name sets anyway, and an empty one defers nothing.
  def mention_names
    Migrations::CompactStringSet.new([])
  end

  def hashtag_names
    Migrations::CompactStringSet.new([])
  end
  before { SiteSetting.enable_markdown_linkify = true }

  # The detector treats an absolute URL as internal only when its host is one it
  # was given; core linkifies any absolute URL regardless. Using the source's own
  # host keeps the two comparable — every row's URL is on it.
  def host
    "forum.example.com"
  end

  def url
    "https://#{host}/t/slug/5"
  end

  # The 32 ASCII punctuation characters (CommonMark), plus letters, whitespace,
  # and the Unicode characters that split core's linkify boundary from a plain
  # "not a word character" one: the wide spaces (NBSP, ideographic space), `²`/`½`
  # (category No), `€` (a currency symbol, category Sc), and `­` (soft hyphen, Cf).
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
    described_class.new(
      embeds: buffer,
      mention_names:,
      hashtag_names:,
      internal_link_hosts: {
        host => nil,
      },
    ).extract(raw)
    buffer.links.any?
  end

  # Core linkifies a bare URL into an anchor whose href is the URL (a trailing
  # character right after the URL may extend the href, so the match is by prefix).
  def core_links?(raw)
    hrefs = PrettyText.cook(raw).scan(/<a\b[^>]*href="([^"]*)"/).flatten
    hrefs.any? { |href| href.start_with?(url) }
  end

  def describe_char(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end

  it "records a link exactly when core linkifies, for every character before the URL" do
    deviations =
      boundary_chars.filter_map do |label, char|
        raw = "a#{char}#{url} b"
        extracted = detector_extracts?(raw)
        linkified = core_links?(raw)
        next if extracted == linkified

        "before #{label} #{describe_char(char)}: detector=#{extracted} core=#{linkified}"
      end
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "records a link exactly when core linkifies, for every character after the URL" do
    deviations =
      boundary_chars.filter_map do |label, char|
        raw = "a #{url}#{char} b"
        extracted = detector_extracts?(raw)
        linkified = core_links?(raw)
        next if extracted == linkified

        "forward #{label} #{describe_char(char)}: detector=#{extracted} core=#{linkified}"
      end
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  # A trailing ASCII letter or `_` extends the URL's `/t/slug/5` id into `5a` / `5_`,
  # which names no topic — so no route parses. On the source's own host the detector
  # still records it, now as a SITE link (origin rewrite), matching core, which
  # linkifies the longer URL all the same.
  it "records a route-less trailing-word URL as a SITE link, matching core's linkify" do
    raw = "a #{url}a b"
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(
      embeds: buffer,
      mention_names:,
      hashtag_names:,
      internal_link_hosts: {
        host => nil,
      },
    ).extract(raw)

    expect(buffer.links.first).to include(
      target_type: Migrations::Database::IntermediateDB::Enums::LinkTarget::SITE,
    )
    expect(core_links?(raw)).to be(true)
  end

  it "records a link at the very start of the input, matching core" do
    raw = "#{url} b"
    expect(detector_extracts?(raw)).to eq(core_links?(raw))
  end

  # Core does not linkify a bare relative path (`/t/slug/5`) in prose — linkify
  # only touches schemed and fuzzy-host URLs — so leaving it literal is parity,
  # not a divergence.
  it "leaves a bare relative path literal, matching core" do
    raw = "see /t/slug/5 here"
    expect(detector_extracts?(raw)).to be(false)
    expect(core_links?(raw)).to be(false)
  end
end
