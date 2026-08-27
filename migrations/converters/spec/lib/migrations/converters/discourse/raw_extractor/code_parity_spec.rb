# frozen_string_literal: true

# Cross-checks the extractor's code handling — the tier gate's routing plus the
# engine tier's certification — against what core actually treats as code.
# Every row plants a sentinel embed — a mention, or an upload where the
# construct swallows an `@` for other reasons — inside or around one construct,
# and asserts the extractor defers exactly when `PrettyText.cook` renders the
# sentinel. Cooked HTML has no notion of "is byte X code", but a sentinel that
# survives cooking is proof the engine parsed that spot as content, which is the
# oracle extraction must agree with.
#
# CommonMark's own `spec.txt` is deliberately not vendored: it asserts HTML, and
# Discourse's engine diverges from it anyway (`[code]`, `<pre>`, bbcode paragraph
# interruption). Its relevant sections — indented code, fenced code, HTML blocks
# type 1, code spans, list items containing code — are hand-translated into rows
# below and so still covered, through the Discourse oracle.
#
# Needs a booted Rails environment, so it is tagged `:rails` and runs only under
# `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  # The extractor requires both name sets; the mention sentinel needs its name in
  # one of them.
  def mention_names
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("alice")])
  end

  def hashtag_names
    Migrations::CompactStringSet.new([])
  end

  def markdown_engine
    MarkdownEngineHelper.context_for_names(hashtag_names: [])
  end

  # The sentinels the rows plant. A mention is the cheap one; an upload is
  # used where a construct swallows an `@` for reasons of its own.
  def mention
    "@alice"
  end

  def upload
    "![shot](upload://abc.png)"
  end

  # Each row is [label, raw]. Verified against PrettyText, 2026-08-01.
  def rows
    [
      # --- <code>, which core does NOT treat as code for mentions ---
      ["bare <code> tag", "x <code>#{mention}</code> y"],
      ["bare <code> tag at line start", "<code>#{mention}</code>"],
      # --- [code] block form ---
      ["[code] block", "[code]\n#{mention}\n[/code]"],
      ["[code=lang] block", "[code=ruby]\n#{mention}\n[/code]"],
      ["[code lang=x] block", "[code lang=ruby]\n#{mention}\n[/code]"],
      ["[CODE] uppercase", "[CODE]\n#{mention}\n[/CODE]"],
      ["[code] block after prose", "intro\n\n[code]\n#{mention}\n[/code]"],
      ["[code] block interrupting a paragraph", "intro\n[code]\n#{mention}\n[/code]"],
      ["[code] opener with trailing spaces", "[code]  \n#{mention}\n[/code]"],
      ["[code] unclosed to EOF", "[code]\n#{mention}\n"],
      ["[code] closer with trailing text", "[code]\n#{mention}\n[/code] x"],
      ["[code] closer indented four", "[code]\n#{mention}\n    [/code]"],
      ["[code] closer indented three", "[code]\n#{mention}\n   [/code]"],
      ["nested [code] blocks", "[code]\n[code]\n#{mention}\n[/code]\n[/code]"],
      ["unbalanced [code] openers", "[code]\n[code]\n#{mention}\n[/code]"],
      ["unbalanced [code] openers, all unclosed", "[code]\n[code]\n#{mention}\n"],
      ["[code] inside a list item", "- item\n\n  [code]\n  #{mention}\n  [/code]"],
      ["[code] inside a blockquote", "> [code]\n> #{mention}\n> [/code]"],
      ["[code] closer outside the blockquote", "> [code]\n> #{mention}\n[/code]"],
      ["[code] body outside the blockquote", "> [code]\n#{mention}\n> [/code]"],
      ["[/code] alone", "[/code]\n#{mention}"],
      # --- [code] inline form ---
      ["[code] inline on its own line", "[code]#{mention}[/code]"],
      ["[code] inline mid-line", "x [code]#{mention}[/code] y"],
      ["[code] inline with trailing text", "[code]#{mention}[/code] tail"],
      ["[code] inline spanning a newline", "intro [code]#{mention}\nmore[/code] tail"],
      ["[code] inline across a blank line", "intro [code]#{mention}\n\nmore[/code] tail"],
      ["[code] inline unclosed", "see [code]#{mention} ok"],
      ["[code] inline with a mismatched-case closer", "see [code]#{mention}[/CODE] x"],
      ["[code] inline over nested brackets", "see [code]a[b][/code] #{mention}"],
      ["[code] inline in a list item", "- [code]#{mention}[/code]"],
      ["[code] inline in a heading", "# [code]#{mention}[/code]"],
      ["[code](url) filling a line", "[code](https://example.com/x) #{mention} y[/code]"],
      ["[code](url) mid-line", "z [code](https://example.com/x) #{mention} y[/code]"],
      # --- other bbcode tags are not code ---
      ["[quote] block", "[quote=\"bob\"]\n#{mention}\n[/quote]"],
      ["[details] block", "[details=\"x\"]\n#{mention}\n[/details]"],
      # --- <pre> HTML block ---
      ["<pre> block", "<pre>\n#{mention}\n</pre>"],
      ["<pre> one-line", "<pre>#{mention}</pre>"],
      ["<pre> with attributes", "<pre class=\"x\">\n#{mention}\n</pre>"],
      ["<pre> indented three", "   <pre>\n#{mention}\n</pre>"],
      ["<pre> indented four", "    <pre>\n#{mention}\n</pre>"],
      ["<pre> mid-line", "x <pre>#{mention}</pre> y"],
      ["<pre> unclosed to EOF", "<pre>\n#{mention}\n"],
      ["<pre> inside a blockquote", "> <pre>\n> #{mention}\n> </pre>"],
      ["text after </pre> on the closing line", "<pre>\nx\n</pre> #{mention}"],
      ["text after a closed <pre>", "<pre>\nx\n</pre>\n\n#{mention}"],
      ["<pre> interrupting a paragraph", "intro\n<pre>\n#{mention}\n</pre>"],
      ["<PRE> uppercase", "<PRE>\n#{mention}\n</PRE>"],
      # --- fenced code ---
      ["fenced block", "```\n#{mention}\n```"],
      ["tilde fence", "~~~\n#{mention}\n~~~"],
      ["tilde does not close a backtick fence", "```\n#{mention}\n~~~\n```"],
      ["fence info with a backtick", "``` a`b\n#{mention}\n```"],
      ["tilde fence info with a backtick", "~~~ a`b\n#{mention}\n~~~"],
      ["fence closer with trailing text", "```\nx\n``` tail\n#{mention}"],
      ["fence indented three", "   ```\n#{mention}\n   ```"],
      ["fence indented four", "Intro\n\n    ```\n#{mention}\n    ```"],
      ["longer closing fence", "```\n#{mention}\n`````"],
      ["shorter run does not close", "````\n#{mention}\n```\nmore"],
      ["closer indented three closes", "```\nx\n   ```\n#{mention}"],
      ["closer indented six does not close", "  ```\n#{mention}\n      ```"],
      ["fence unclosed to EOF", "```\n#{mention}"],
      ["fence inside a blockquote", "> ```\n> #{mention}\n> ```"],
      ["fence broken by an unprefixed line", "> ```\n#{mention}\n> ```"],
      ["fence inside a list item", "- item\n\n  ```\n  #{mention}\n  ```"],
      ["fence closing a list", "- item\n\n```\n#{mention}\n```"],
      ["text after a closed fence", "```\nx\n```\n\n#{mention}"],
      # --- indented code ---
      ["indented after a blank line", "Intro\n\n    #{mention}"],
      ["indented at the start of input", "    #{mention}"],
      ["indented as a lazy continuation", "Intro\n    #{mention}"],
      ["indented after a heading without a blank line", "# Title\n    #{mention}"],
      ["indented after a closed fence without a blank line", "```\nx\n```\n    #{mention}"],
      ["indented after a thematic break", "Intro\n***\n\n    #{mention}"],
      ["indented after a setext heading", "Intro\n===\n    #{mention}"],
      ["indented after a dash underline", "Intro\n-\n    #{mention}"],
      ["indented after a two-dash underline", "Intro\n--\n    #{mention}"],
      ["indented after an underline in a blockquote", "> Intro\n> -\n>     #{mention}"],
      ["indented after a lone dash", "-\n    #{mention}"],
      ["indented after a lone equals", "=\n    #{mention}"],
      ["indented after two dashes alone", "--\n    #{mention}"],
      ["indented after two equals alone", "==\n    #{mention}"],
      ["indented after a lone star", "*\n    #{mention}"],
      ["indented after a spaced break", "- - -\n    #{mention}"],
      ["indented after spaced equals under a paragraph", "Intro\n= =\n    #{mention}"],
      ["indented after spaced dashes under a paragraph", "Intro\n- -\n    #{mention}"],
      ["indented after a lazy dash in a blockquote", "> Intro\n-\n      #{mention}"],
      ["indented after a lazy equals in a blockquote", "> Intro\n=\n    #{mention}"],
      ["indented after lazy dashes in a blockquote", "> Intro\n--\n    #{mention}"],
      ["indented after a break leaving a blockquote", "> Intro\n---\n    #{mention}"],
      ["indented after a lazy equals in a list", "- Intro\n=\n      #{mention}"],
      ["lazy [code] in a blockquote", "> Intro\n[code]\n#{mention}\n[/code]"],
      ["two columns after a lazy dash in a blockquote", "> Intro\n-\n    #{mention}"],
      ["indented after a lazy dash in a list", "- Intro\n-\n      #{mention}"],
      ["indented after a lazy star in a blockquote", "> Intro\n*\n      #{mention}"],
      ["indented after a lazy star under a paragraph", "Intro\n*\n    #{mention}"],
      ["indented after a lazy ordered item under a paragraph", "Intro\n2. x\n    #{mention}"],
      ["indented after a lazy ordered item in a blockquote", "> Intro\n2. x\n       #{mention}"],
      ["indented after a lazy heading in a list", "- Intro\n# h\n    #{mention}"],
      ["lazy <pre> in a list", "- Intro\n<pre>\n#{mention}\n</pre>"],
      ["lazy [code] in a list", "- Intro\n[code]\n#{mention}\n[/code]"],
      ["indented after an underline with trailing spaces", "Intro\n-  \n    #{mention}"],
      ["two columns after a lazy dash in a list", "- Intro\n-\n    #{mention}"],
      ["indented after a lazy star in a list", "- Intro\n*\n      #{mention}"],
      ["indented in a lazy ordered item's second block", "- Intro\n2. x\n\n      #{mention}"],
      ["two columns in a lazy ordered item's second block", "> Intro\n2. x\n\n     #{mention}"],
      ["tab-indented after a blank line", "Intro\n\n\t#{mention}"],
      ["space then tab reaching column four", "Intro\n\n \t#{mention}"],
      ["two columns is not enough", "Intro\n\n  #{mention}"],
      ["indented block with a blank line inside", "Intro\n\n    a\n\n    #{mention}"],
      ["unindented line closes an indented block", "Intro\n\n    a\ntext\n\n    #{mention}"],
      ["four columns under a bullet", "- item\n    #{mention}"],
      ["four columns under a bullet after a blank line", "- item\n\n    #{mention}"],
      ["six columns under a bullet", "- item\n\n      #{mention}"],
      ["six columns under a bullet with a wide marker", "-     item\n\n      #{mention}"],
      ["five columns under a bullet with a wide marker", "-     item\n\n     #{mention}"],
      ["four columns under a numbered step", "1. Step\n\n    #{mention}"],
      ["seven columns under a numbered step", "1. Step\n\n       #{mention}"],
      ["tab after a bullet marker", "-\titem\n\n\t\t#{mention}"],
      ["eight columns under a nested bullet", "- a\n\n  - b\n\n        #{mention}"],
      ["six columns under a nested bullet", "- a\n\n  - b\n\n      #{mention}"],
      ["indented inside a blockquote", "> Intro\n>\n>     #{mention}"],
      ["indented after a blockquote", "> a\n\n    #{mention}"],
      ["indented after a list has ended", "- item\n\ntext\n\n    #{mention}"],
      [
        "indented right after a fence closed in a list",
        "- item\n\n  ```\n  x\n  ```\n      #{mention}",
      ],
      ["a bullet's own line is not code", "- item\n#{mention}"],
      ["blockquote lazy continuation", "> a\n#{mention}"],
      # --- inline span bounds (a backtick opener that must stay literal) ---
      ["backtick span across a plain line", "`x\nplain text\n#{mention}`"],
      ["backtick span across a blank line", "`x\n\n#{mention}`"],
      ["backtick span across a heading", "`x\n# h\n#{mention}`"],
      ["backtick span across a setext underline", "`x\n===\n#{mention}`"],
      ["backtick span across a dash underline", "`x\n---\n#{mention}`"],
      ["backtick span across a bullet", "`x\n- b\n#{mention}`"],
      ["backtick span across a plus bullet", "`x\n+ b\n#{mention}`"],
      ["backtick span across a numbered item", "`x\n1. b\n#{mention}`"],
      ["backtick span across a paren-numbered item", "`x\n1) b\n#{mention}`"],
      ["backtick span across a later-numbered item", "`x\n2. b\n#{mention}`"],
      ["backtick span across a lone star", "`x\n*\n#{mention}`"],
      ["backtick span across a blockquote", "`x\n> b\n#{mention}`"],
      ["backtick span across a thematic break", "`x\n***\n#{mention}`"],
      ["backtick span across a table", "`x\na|b\n-|-\nc|d\n#{mention}`"],
      ["backtick span across a bbcode opener", "`x\n[quote=\"bob\"]\n#{mention}`"],
      ["backtick span across a fence opener", "`x\n```\n#{mention}`"],
      ["backtick span across a <pre> opener", "`x\n<pre>\n#{mention}`"],
      ["backtick span across an indented line", "`x\n    y\n#{mention}`"],
      ["backtick span inside a blockquote", "> `x\n> y\n> #{mention}`"],
      ["backtick span over a blockquote's lazy line", "> `x\ny\n> #{mention}`"],
      # --- multibyte padding, for byte-offset discipline ---
      ["multibyte before an indented block", "Ümläut\n\n    #{mention}"],
      ["multibyte inside a fence", "```\nÜ #{mention}\n```"],
      ["multibyte inside a [code] block", "[code]\nÜ #{mention}\n[/code]"],
      ["multibyte before an inline [code] span", "Ü [code]#{mention}[/code] ok"],
      ["multibyte before a backtick span", "Ü `#{mention}` ok"],
      ["multibyte inside a <pre> block", "<pre>\nÜ #{mention}\n</pre>"],
      ["multibyte inside a list item", "- ïtem\n\n      #{mention}"],
      # --- CRLF, which markdown-it normalizes before parsing ---
      ["CRLF fenced block", "```\r\n#{mention}\r\n```\r\n"],
      ["CRLF indented block", "Intro\r\n\r\n    #{mention}\r\n"],
      ["CRLF [code] block", "[code]\r\n#{mention}\r\n[/code]\r\n"],
      # --- upload sentinels, the embed whose loss is permanent ---
      ["upload in a fence", "```\n#{upload}\n```"],
      ["upload in a [code] block", "[code]\n#{upload}\n[/code]"],
      ["upload in an inline [code] span", "a [code]#{upload}[/code] b"],
      ["upload in a <pre> block", "<pre>\n#{upload}\n</pre>"],
      ["upload in a backtick span", "a `#{upload}` b"],
      ["upload indented after a blank line", "Intro\n\n    #{upload}"],
      ["upload indented under a bullet", "- item\n\n      #{upload}"],
      ["upload as a lazy continuation", "Intro\n    #{upload}"],
      ["upload after a closed [code] block", "[code]\nx\n[/code]\n\n#{upload}"],
      # --- spans over constructs the line-oriented walk once resolved wrong ---
      # An unregistered bbcode tag, an unknown HTML tag, a closing HTML tag,
      # and a table interrupting a paragraph were documented divergences of the
      # deleted line-oriented walk; the engine tier reads them exactly as core.
      ["backtick span across an unregistered bbcode tag", "`x\n[foo]\n#{mention}`"],
      ["backtick span across an unknown HTML tag", "`x\n<pretty>\n#{mention}`"],
      ["backtick span across a closing HTML tag", "`x\n</pre>\n#{mention}`"],
      [
        "indented line below a table interrupting a paragraph",
        "Intro\na|b\n-|-\nc|d\n    #{mention}",
      ],
    ]
  end

  # Whether the extractor left the sentinel alone, i.e. read it as code.
  def construct_treats_as_code?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:).extract(
      raw,
    )
    raw.include?(upload) ? buffer.uploads.empty? : buffer.mentions.empty?
  end

  # Whether core rendered the sentinel, i.e. read it as content. A mention that
  # names nobody still cooks an inert `<span class="mention">`, which is enough:
  # the question is whether the engine saw a mention token at all.
  def core_treats_as_code?(raw)
    cooked = PrettyText.cook(raw)
    marker = raw.include?(upload) ? "<img" : 'class="mention"'
    !cooked.include?(marker)
  end

  it "reads every construct as code exactly when core does" do
    deviations =
      rows.filter_map do |label, raw|
        detected = construct_treats_as_code?(raw)
        cooked = core_treats_as_code?(raw)
        next if detected == cooked

        "#{label} (#{raw.inspect}): tracker=#{detected} core=#{cooked}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end
end
