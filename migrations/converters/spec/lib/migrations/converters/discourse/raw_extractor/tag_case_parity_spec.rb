# frozen_string_literal: true

# Cross-checks case folding against core, construct by construct. They do not
# agree with each other, and the split is not guessable:
#
#   * core's bbcode *block* rules fold case — `[CODE]`, `[QUOTE=…]` render the
#     same as their lower-case forms, and so does `<PRE>`;
#   * the `|attachment]` marker folds case too, but it only picks the CSS class:
#     any markdown link to `upload://` carries `data-orig-href` either way, so
#     the upload is real and has to be recorded;
#   * the `upload://` scheme itself does NOT fold. `UPLOAD://` cooks a link with
#     no `data-orig-href` — nothing the importer could resolve.
#
# Getting one wrong is silent in both directions. Too strict and a construct core
# rendered is never rewritten, so its ids stay the source's; too loose and we
# replace text core showed as-is. Both had happened, which is why every construct
# gets a row rather than only the ones that looked doubtful.
#
# Needs a booted Rails environment, so it is tagged `:rails` and runs only under
# `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  let(:mention_names) do
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("alice")])
  end

  let(:hashtag_names) { Migrations::CompactStringSet.new([]) }
  let(:markdown_engine) { MarkdownEngineHelper.context_for_names(hashtag_names: []) }

  # Constructs whose content core treats as code: the sentinel mention must
  # survive cooking as plain text, and we must leave the body alone.
  def code_rows
    {
      "[code]" => "[code]\n@alice\n[/code]",
      "[CODE]" => "[CODE]\n@alice\n[/CODE]",
      "[code] with an upper-case closer" => "[code]\n@alice\n[/CODE]",
      "<pre>" => "<pre>\n@alice\n</pre>",
      "<PRE>" => "<PRE>\n@alice\n</PRE>",
    }
  end

  # Constructs core renders as a quote block, which we must record so its
  # coordinates are remapped.
  def quote_rows
    {
      "[quote=…]" => %([quote="alice, post:1, topic:2"]\nx\n[/quote]),
      "[QUOTE=…]" => %([QUOTE="alice, post:1, topic:2"]\nx\n[/QUOTE]),
    }
  end

  # label => [raw, whether core resolves the upload]
  def upload_rows
    {
      "an image" => ["![x](upload://abc123.png)", true],
      "an image with an upper-case scheme" => ["![x](UPLOAD://abc123.png)", false],
      "an attachment" => ["[r.pdf|attachment](upload://abc123.png)", true],
      "an upper-case attachment marker" => ["[r.pdf|ATTACHMENT](upload://abc123.png)", true],
      "an attachment with an upper-case scheme" => [
        "[r.pdf|attachment](UPLOAD://abc123.png)",
        false,
      ],
    }
  end

  def extract(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    result =
      described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:).extract(
        raw,
      )
    [buffer, result]
  end

  it "leaves the body of every code form alone, as core does" do
    deviations =
      code_rows.filter_map do |label, raw|
        buffer, result = extract(raw)
        core_kept_it_literal = !PrettyText.cook(raw).include?('class="mention"')
        next if core_kept_it_literal && buffer.mentions.empty? && result == raw

        "#{label}: core_literal=#{core_kept_it_literal} ours_rewrote=#{result != raw}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "records every quote form core renders as a quote" do
    deviations =
      quote_rows.filter_map do |label, raw|
        buffer, = extract(raw)
        core_quotes = PrettyText.cook(raw).include?('class="quote')
        next if core_quotes && buffer.quotes.size == 1

        "#{label}: core_quotes=#{core_quotes} ours_recorded=#{buffer.quotes.size}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "records an upload exactly when core resolves one" do
    deviations =
      upload_rows.filter_map do |label, (raw, expected)|
        buffer, = extract(raw)
        cooked = PrettyText.cook(raw)
        core_resolves = cooked.include?("data-orig-src") || cooked.include?("data-orig-href")
        ours = buffer.uploads.any?
        next if core_resolves == expected && ours == expected

        "#{label} (#{raw.inspect}): expected=#{expected} core=#{core_resolves} ours=#{ours}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end
end
