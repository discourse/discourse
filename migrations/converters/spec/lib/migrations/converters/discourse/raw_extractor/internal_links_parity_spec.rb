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

  def markdown_engine
    MarkdownEngineHelper.context_for_names(hashtag_names: [])
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

  # Whether the extractor treated the URL core linkifies as an internal link:
  # a recorded row, or a deliberate refusal — a trailing character can extend
  # the id into a coordinate-shaped junk path (`…/5a`), which refuses rather
  # than origin-rewriting stale coordinates. What the boundary suite proves is
  # that the URL's EXTENT matches linkify; what becomes of the extended URL is
  # the coordinate rule's own specs' concern.
  def detector_extracts?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    extractor =
      described_class.new(
        embeds: buffer,
        markdown_engine:,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          host => nil,
        },
      )
    extractor.extract(raw)
    buffer.links.any? || extractor.engine_refusals[:unanchored] > 0
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
  # which names no topic — so no route parses. Core linkifies the longer URL
  # all the same, and the extractor sees it whole; but a coordinate-shaped
  # path that parses no route refuses rather than carrying its stale-looking
  # tail onto a new origin, so the body stays verbatim and lands on the
  # refusal tally.
  it "refuses a coordinate-shaped trailing-word URL that core linkifies whole" do
    raw = "a #{url}a b"
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    extractor =
      described_class.new(
        embeds: buffer,
        markdown_engine:,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          host => nil,
        },
      )

    expect(extractor.extract(raw)).to eq(raw)
    expect(buffer.links).to be_empty
    expect(extractor.engine_refusals).to eq(unanchored: 1)
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
