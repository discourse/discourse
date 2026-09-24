# frozen_string_literal: true

# Cross-checks the custom-emoji construct against what core actually renders. For
# every boundary character in a representative set we build `a<char>:parrot: x`
# (and the forward variant `a :parrot:<char> x`) and assert the construct defers
# exactly when `PrettyText.cook` renders the source's custom emoji.
#
# The deliberate divergence: this construct defers only the source's *custom*
# emoji. A standard shortcode (`:smile:`) cooks in core too, but it needs no
# remapping and round-trips verbatim, so we leave it literal on purpose. The
# core-side predicate is therefore "core rendered THE CUSTOM emoji" — an
# `emoji-custom` image for the test name — with a real CustomEmoji in the DB, not
# just "core rendered some emoji".
#
# Core's emoji rule uses its own boundary (`isValidEmojiPrecedingChar`: markdown-
# it's narrow `isSpace`, `isPunctChar`, or a zero-width space), not the wider
# whitespace-or-punctuation boundary mentions and hashtags run through, so the two
# sides are checked here against PrettyText rather than read off the rule's regex.
# Needs a booted Rails environment, so it is tagged `:rails` and runs only under
# `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  include_context "with parity extractor"

  before do
    SiteSetting.enable_emoji = true
    # The mode where the preceding-character boundary is enforced (with inline
    # emoji translation on, core skips it and any character opens a shortcode).
    SiteSetting.enable_inline_emoji_translation = false
  end

  # A real CustomEmoji is what core cooks into an `emoji-custom` image; a standard
  # or unknown shortcode does not. Clearing the cache makes the fresh record
  # visible to PrettyText.
  def create_custom_emoji(name)
    CustomEmoji.create!(name:, upload: Fabricate(:upload))
    Emoji.clear_cache
  end

  before { create_custom_emoji("parrot") }

  def markdown_engine_for(name)
    MarkdownEngineHelper.context_for_names(hashtag_names: [], custom_emoji_names: [name])
  end

  def construct_extracts?(raw, name = "parrot")
    buffer = new_buffer
    build_extractor(
      buffer,
      markdown_engine: markdown_engine_for(name),
      custom_emoji_names: [name],
    ).extract(raw)
    buffer.emojis.any? { |emoji| emoji[:name] == name }
  end

  # Core cooks a custom emoji into an `<img class="emoji emoji-custom" …>` whose
  # title is `:name:`. A standard shortcode cooks a plain `emoji` image (no
  # `emoji-custom`), so this tells apart the source's own emoji.
  def core_cooks?(raw, name = "parrot")
    html = PrettyText.cook(raw)
    html.include?('class="emoji emoji-custom"') && html.include?(%(title=":#{name}:"))
  end

  def deviations_for(direction)
    BoundaryCorpus
      .chars(zero_width_space: true)
      .filter_map do |label, char|
        raw = direction == :before ? "a#{char}:parrot: x" : "a :parrot:#{char} x"
        extracted = construct_extracts?(raw)
        cooked = core_cooks?(raw)
        next if extracted == cooked

        "#{direction} #{label} #{BoundaryCorpus.describe(char)}: construct=#{extracted} core=#{cooked}"
      end
  end

  it "defers exactly when core cooks, for every character before the opening `:`" do
    deviations = deviations_for(:before)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "defers exactly when core cooks, for every character after the closing `:`" do
    deviations = deviations_for(:forward)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "defers a shortcode at the very start of the input, matching core" do
    raw = ":parrot: x"
    expect(construct_extracts?(raw)).to eq(core_cooks?(raw))
  end

  it "defers each shortcode of an adjacent chain, matching core" do
    raw = "look :parrot::parrot: x"
    expect(construct_extracts?(raw)).to be(true)
    expect(core_cooks?(raw)).to be(true)
  end

  it "keeps a toned shortcode literal, matching core" do
    # `:parrot:t4:` resolves to a toned standard emoji, never the custom one, so
    # both sides leave it as written.
    raw = "wave :parrot:t4: here"
    expect(construct_extracts?(raw)).to be(false)
    expect(core_cooks?(raw)).to be(false)
  end

  it "defers a tone-like suffix that has no closing colon, matching core" do
    raw = "wave :parrot:t4 here"
    expect(construct_extracts?(raw)).to be(true)
    expect(core_cooks?(raw)).to be(true)
  end

  it "leaves a `:name:` inside a clock time literal, matching core" do
    # A digit before the `:` is not a boundary, so `10:30:45` never opens a
    # shortcode — even with a custom emoji named after the middle segment.
    create_custom_emoji("30")
    raw = "meet at 10:30:45 sharp"
    expect(construct_extracts?(raw, "30")).to be(false)
    expect(core_cooks?(raw, "30")).to be(false)
  end

  it "defers a custom emoji whose name holds `+` and digits, matching core" do
    create_custom_emoji("+1")
    raw = "nice :+1: work"
    expect(construct_extracts?(raw, "+1")).to be(true)
    expect(core_cooks?(raw, "+1")).to be(true)
  end
end
