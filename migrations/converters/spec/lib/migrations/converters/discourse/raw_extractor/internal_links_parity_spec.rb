# frozen_string_literal: true

# Cross-checks the internal-link construct's bare-URL boundary against what core
# actually renders. For every boundary character in a representative set we build
# `a<char>https://forum.example.com/t/slug/5 b` (and the forward variant with the
# character right after the URL) and assert the construct records a link exactly
# when `PrettyText.cook` linkifies an anchor for that URL.
#
# Core's machinery for a bare absolute URL in prose is markdown-it's linkify, fed
# by two engines whose admissions are unioned: the inline rule
# (`markdown-it/rules_inline/linkify.mjs`, a scheme after anything outside
# `[A-Za-z0-9.+-]`) and the core ruler (`rules_core/linkify.mjs` via linkify-it,
# which also admits `.` and `-`). The net boundary before a scheme is "any
# character except an ASCII letter, digit or `+`" (and `\`, a markdown escape) —
# far wider than the whitespace-or-paren gate the construct used to admit at, so it
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

  # The construct treats an absolute URL as internal only when its host is one it
  # was given; core linkifies any absolute URL regardless. Using the source's own
  # host keeps the two comparable — every row's URL is on it.
  def host
    "forum.example.com"
  end

  def url
    "https://#{host}/t/slug/5"
  end

  def build_extractor(buffer)
    described_class.new(
      embeds: buffer,
      markdown_engine:,
      mention_names:,
      hashtag_names:,
      internal_link_hosts: {
        host => nil,
      },
    )
  end

  # What the extractor did with the URL: `:link` (a row was recorded),
  # `:refused` (the body landed on the refusal tally), or `:none`.
  def construct_outcome(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    extractor = build_extractor(buffer)
    extractor.extract(raw)
    return :link if buffer.links.any?

    extractor.engine_refusals.values.sum > 0 ? :refused : :none
  end

  # Core linkifies a bare URL into an anchor whose href is the URL. A trailing
  # character right after the URL may extend the href; `extended` reports that,
  # because an extended href is the one case where the extractor may refuse
  # instead of recording a link (the extension can turn the id into a junk
  # coordinate path).
  def core_reading(raw)
    hrefs = PrettyText.cook(raw).scan(/<a\b[^>]*href="([^"]*)"/).flatten
    matching = hrefs.select { |href| href.start_with?(url) }
    { linkified: matching.any?, extended: matching.any? { |href| href.length > url.length } }
  end

  it "records a link exactly when core linkifies, for every character before the URL" do
    deviations =
      LinkifyBoundaryCorpus.chars.filter_map do |label, char|
        raw = "a#{char}#{url} b"
        outcome = construct_outcome(raw)
        core = core_reading(raw)

        if (outcome != :none) != core[:linkified]
          "before #{label} #{LinkifyBoundaryCorpus.describe(char)}: " \
            "construct=#{outcome} core=#{core[:linkified]}"
        elsif outcome == :refused
          # Nothing follows the URL here, so its route is intact; a refusal
          # would hide a regression from recording links to refusing them.
          "before #{label} #{LinkifyBoundaryCorpus.describe(char)}: refused instead of recording"
        end
      end
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "records a link exactly when core linkifies, for every character after the URL" do
    deviations =
      LinkifyBoundaryCorpus.chars.filter_map do |label, char|
        raw = "a #{url}#{char} b"
        outcome = construct_outcome(raw)
        core = core_reading(raw)

        if (outcome != :none) != core[:linkified]
          "forward #{label} #{LinkifyBoundaryCorpus.describe(char)}: " \
            "construct=#{outcome} core=#{core[:linkified]}"
        elsif outcome == :refused && !core[:extended]
          # A refusal is only right when core swallowed the character into the
          # href and made the trailing id a junk coordinate path. With the
          # href unchanged, refusing instead of recording is a regression.
          "forward #{label} #{LinkifyBoundaryCorpus.describe(char)}: refused instead of recording"
        end
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
    extractor = build_extractor(buffer)

    expect(extractor.extract(raw)).to eq(raw)
    expect(buffer.links).to be_empty
    expect(extractor.engine_refusals).to eq(invalid_internal_route: 1)
    expect(core_reading(raw)[:linkified]).to be(true)
  end

  it "records a link at the very start of the input, matching core" do
    raw = "#{url} b"
    expect(construct_outcome(raw)).to eq(:link)
    expect(core_reading(raw)[:linkified]).to be(true)
  end

  # Core does not linkify a bare relative path (`/t/slug/5`) in prose — linkify
  # only touches schemed and fuzzy-host URLs — so leaving it literal is parity,
  # not a divergence.
  it "leaves a bare relative path literal, matching core" do
    raw = "see /t/slug/5 here"
    expect(construct_outcome(raw)).to eq(:none)
    expect(core_reading(raw)[:linkified]).to be(false)
  end
end
