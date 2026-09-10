# frozen_string_literal: true

require "cgi"

# Cross-checks the quote construct's header reading and its trailing-space forward
# check against what core actually renders. Core parses `[quote=…]` through
# discourse-markdown-it's bbcode-block.js block rule, which accepts an unquoted
# header and strips a range of quotation-mark pairs, and only renders the block
# when nothing but spaces or tabs follows the opening tag to the end of its line.
# For each header shape we assert the construct defers exactly when
# `PrettyText.cook` renders a `<aside class="quote">`, and reads back the same
# username core put on it. Needs a booted Rails environment, so it is tagged
# `:rails` and runs only under `MIGRATIONS_RAILS=1`.
#
# The construct deliberately skips core's block-position rules (line start, a real
# `[/quote]` further down, list context) — matching those would need whole-
# document machinery, and over-extracting a `[quote=…]` that core left as raw
# BBCode only renumbers text in place at import. So a handful of rows are known,
# accepted divergences rather than parity; they are pinned separately below so a
# future change in our behavior is noticed.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  include_context "with parity extractor"

  def construct_quote(raw)
    buffer = new_buffer
    build_extractor(buffer).extract(raw)
    buffer.quotes.first
  end

  def construct_extracts?(raw)
    !construct_quote(raw).nil?
  end

  def construct_username(raw)
    construct_quote(raw)&.[](:quoted_username)
  end

  def core_html(raw)
    PrettyText.cook(raw)
  end

  def core_renders_quote?(raw)
    core_html(raw).include?('<aside class="quote')
  end

  # The username core put on the aside, with the HTML entities it escapes (a
  # literal `"` in a mismatched header cooks as `&quot;`) turned back so it
  # compares to the construct's raw header value.
  def core_username(raw)
    escaped = core_html(raw)[/data-username="([^"]*)"/, 1]
    escaped && CGI.unescapeHTML(escaped)
  end

  # Header shapes that are parity: the construct defers exactly when core renders,
  # and reads back the same username. Each `\n` right after the opening tag is the
  # trailing-space forward check's happy path (a bare line end). The username is
  # the value core strips down to, so the mismatched and empty-pair rows keep the
  # quote marks as literal header characters, matching core.
  #
  #   label => [raw, expected username]
  def parity_headers
    {
      "unquoted plain" => [%([quote=bob]\nx\n[/quote]), "bob"],
      "unquoted with parts" => [%([quote=bob, post:1, topic:2]\nx\n[/quote]), "bob"],
      "unquoted leading space" => [%([quote= bob]\nx\n[/quote]), "bob"],
      "straight double" => [%([quote="bob"]\nx\n[/quote]), "bob"],
      "straight double with parts" => [%([quote="bob, post:1, topic:2"]\nx\n[/quote]), "bob"],
      "straight single" => [%([quote='bob']\nx\n[/quote]), "bob"],
      "curly double" => [%([quote=“bob”]\nx\n[/quote]), "bob"],
      "guillemet" => [%([quote=«bob»]\nx\n[/quote]), "bob"],
      "curly single" => [%([quote=‘bob’]\nx\n[/quote]), "bob"],
      "low double quote" => [%([quote=„bob“]\nx\n[/quote]), "bob"],
      "double right-right" => [%([quote=”bob”]\nx\n[/quote]), "bob"],
      "low single" => [%([quote=‚bob’]\nx\n[/quote]), "bob"],
      "single guillemet" => [%([quote=‹bob›]\nx\n[/quote]), "bob"],
      "explicit username" => [
        %([quote="Bob Jones, post:1, username:bjones"]\nx\n[/quote]),
        "bjones",
      ],
      "explicit username with a comma name" => [
        %([quote="Doe, John, post:1, username:jd"]\nx\n[/quote]),
        "jd",
      ],
      "comma name without explicit username" => [
        %([quote="Doe, John, post:1"]\nx\n[/quote]),
        "Doe",
      ],
      "mismatched double-single" => [%([quote="bob']\nx\n[/quote]), %("bob')],
      "mismatched single-double" => [%([quote='bob"]\nx\n[/quote]), %('bob")],
      "one-sided opening mark" => [%([quote="bob]\nx\n[/quote]), %("bob)],
      "one-sided closing mark" => [%([quote=bob"]\nx\n[/quote]), %(bob")],
      "empty straight double" => [%([quote=""]\nx\n[/quote]), %("")],
      "empty straight single" => [%([quote='']\nx\n[/quote]), "''"],
      "empty curly double" => [%([quote=“”]\nx\n[/quote]), "“”"],
      "trailing spaces only" => [%([quote="bob"]   \nx\n[/quote]), "bob"],
      "trailing tab only" => [%([quote="bob"]\t\nx\n[/quote]), "bob"],
      "own paragraph after text" => [%(text\n\n[quote="bob"]\nx\n[/quote]), "bob"],
      "line start after text" => [%(text\n[quote="bob"]\nx\n[/quote]), "bob"],
    }
  end

  # Headers that name nobody: core renders no aside (`[quote=]`, `[quote= ]`) and
  # neither do we.
  def parity_non_quotes
    {
      "empty header" => %([quote=]\nx\n[/quote]),
      "whitespace-only header" => %([quote= ]\nx\n[/quote]),
      "trailing text after tag" => %([quote="bob"] hello\nx\n[/quote]),
      "trailing text unquoted" => %([quote=bob] hello\nx\n[/quote]),
    }
  end

  it "defers exactly when core renders, reading back the same username" do
    deviations =
      parity_headers.filter_map do |label, (raw, expected)|
        construct = construct_username(raw)
        core = core_username(raw)
        next if construct == expected && core == expected

        "#{label}: construct=#{construct.inspect} core=#{core.inspect} expected=#{expected.inspect}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "leaves headerless and no-username shapes alone, matching core" do
    deviations =
      parity_non_quotes.filter_map do |label, raw|
        next if !construct_extracts?(raw) && !core_renders_quote?(raw)

        "#{label}: construct=#{construct_extracts?(raw)} core=#{core_renders_quote?(raw)}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "extracts a header at the very start of the input, matching core" do
    raw = %([quote="bob"]\nx\n[/quote])
    expect(construct_extracts?(raw)).to eq(core_renders_quote?(raw))
    expect(construct_username(raw)).to eq(core_username(raw))
  end

  it "reads a comma-containing display name back the way core joins it" do
    # quotes.js splits the header on commas and joins everything before the
    # `post:` part back together as the display name.
    raw = %([quote="Doe, John, post:1, username:jd"]\nx\n[/quote])
    expect(construct_quote(raw)).to include(quoted_username: "jd", quoted_name: "Doe, John")
    expect(core_html(raw)).to include("Doe, John")
  end

  it "treats a CRLF after the tag as a bare line end, matching core" do
    # markdown-it normalizes CR/CRLF to LF before it parses, so core renders a
    # quote whose opening tag is followed only by a CRLF; the forward check reads
    # the `\r` as a line end for the same reason.
    raw = %([quote="bob"]\r\nx\r\n[/quote])
    expect(construct_extracts?(raw)).to be(true)
    expect(core_renders_quote?(raw)).to be(true)
  end

  # Block position comes from the engine's parsed quote tokens, so a tag core
  # leaves as raw BBCode is never extracted — the old line-oriented walk
  # over-extracted every one of these.
  describe "block position through the engine tier" do
    it "leaves a mid-line tag alone, like core" do
      # Not at a line start, so core renders nothing and neither do we.
      raw = %(some text [quote="bob"]\nx\n[/quote])
      expect(construct_extracts?(raw)).to be(false)
      expect(core_renders_quote?(raw)).to be(false)
    end

    it "leaves a tag inside a list item alone, like core" do
      raw = %(- [quote="bob"]\nx\n[/quote])
      expect(construct_extracts?(raw)).to be(false)
      expect(core_renders_quote?(raw)).to be(false)
    end

    it "leaves an unclosed quote alone, like core" do
      raw = %([quote="bob"]\nx\nno closing tag here)
      expect(construct_extracts?(raw)).to be(false)
      expect(core_renders_quote?(raw)).to be(false)
    end

    it "extracts core's single-line inline form through the engine tier" do
      # The line-oriented walk's forward check had to decline this shape; the
      # engine tier takes block context from the parsed quote token, so
      # the header is remapped exactly where core renders it.
      raw = %([quote="bob"]body[/quote])
      expect(construct_extracts?(raw)).to be(true)
      expect(core_renders_quote?(raw)).to be(true)
    end

    it "leaves a headerless [quote] alone where core renders an anonymous aside" do
      # Nothing to remap without a header, so we defer to the importer's re-cook.
      raw = %([quote]\nx\n[/quote])
      expect(construct_extracts?(raw)).to be(false)
      expect(core_renders_quote?(raw)).to be(true)
    end
  end
end
