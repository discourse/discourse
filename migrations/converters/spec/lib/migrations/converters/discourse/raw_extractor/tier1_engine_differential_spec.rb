# frozen_string_literal: true

# The tier-1 claim: on a body the TierGate classifies as prose, plain
# boundary-checked detector matches find exactly the constructs the real
# discourse-markdown-it engine finds — there is no code to shield and no link
# structure to honor, by the gate's own definition. This differential runs the
# same bodies through both sides and compares the construct sets. The engine
# context needs no Rails, so the whole check runs in the isolated suite; the
# corpus below is the seed and is meant to grow whenever a divergence class is
# suspected.
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  # Overrides the shared context's extractor: the differential also exercises
  # custom emoji, so the detector needs its names. Defined after the include
  # so this definition is the one in effect.
  let(:extractor) do
    described_class.new(embeds: buffer, mention_names:, hashtag_names:, custom_emoji_names:)
  end

  let(:custom_emoji_names) { %w[parrot] }
  let(:category_slugs) { %w[support] }
  let(:tag_names) { %w[release] }

  let(:engine) do
    Migrations::Converters::MarkdownEngine::Context.new(
      bundle: Migrations::Converters::MarkdownEngine::Bundle.load_or_build,
      config:
        Migrations::Converters::MarkdownEngine::Config.new(
          source_settings: {
            "unicode_usernames" => true,
          },
          category_slugs:,
          tag_names:,
          custom_emoji_names:,
        ),
    )
  end

  after { engine.close }

  # Bodies must stay inside tier 1: no code, no escapes, no HTML, no link
  # syntax, no CR, no construct-capable entity. A case that drifts out of the
  # class fails the classification guard below rather than silently testing
  # nothing.
  let(:cases) do
    [
      "hello @alice, welcome",
      "@alice at the start and @bob at the end: @carol.",
      "punctuated (@alice) and quoted \"@bob\" mentions",
      "no mention in an email alice@example.com",
      "unknown @nobody stays untouched",
      "hashtag #support in prose",
      "sentence-final #support.",
      "not hashtags: PR #123, word#support",
      "custom :parrot: and standard :smile: emoji",
      "shortcodes back to back :parrot::parrot:",
      "a mention right before punctuation @alice, and #support!",
      "unicode mention @café_team works",
    ]
  end

  def tier1_constructs(raw)
    buffer.clear
    extractor.extract(raw)
    {
      mentions: buffer.mentions.map { |row| row[:name].downcase }.sort,
      hashtags: buffer.hashtags.map { |row| row[:name].downcase }.sort,
      emojis: buffer.emojis.map { |row| row[:name] }.sort,
    }
  end

  def engine_constructs(raw)
    blocks = engine.scan([{ id: 1, raw: }]).first["blocks"]
    mentions =
      blocks
        .flat_map { |block| block["mentions"] }
        .map { |value| Migrations::NameNormalizer.normalize(value.delete_prefix("@")) }
        .filter { |name| mention_names.include?(name) }
    hashtags =
      blocks
        .flat_map { |block| block["hashtags"] }
        .map { |hashtag| hashtag["slug"].sub(/::(tag|category)\z/, "").downcase }
    emojis =
      blocks
        .flat_map { |block| block["emojis"] }
        .filter { |name| custom_emoji_names.include?(name) }

    { mentions: mentions.sort, hashtags: hashtags.sort, emojis: emojis.sort }
  end

  it "finds exactly the constructs the engine finds on tier-1 bodies" do
    cases.each do |raw|
      classification =
        Migrations::Converters::Discourse::MarkdownScanner::TierGate.new(
          detectors: [
            Migrations::Converters::Discourse::MarkdownScanner::Detectors::Mention.new(
              names: mention_names,
            ),
            Migrations::Converters::Discourse::MarkdownScanner::Detectors::Hashtag.new(
              names: hashtag_names,
            ),
            Migrations::Converters::Discourse::MarkdownScanner::Detectors::Emoji.new(
              names: custom_emoji_names,
            ),
          ],
        ).classify(raw)
      expect(classification).to eq(:prose).or(eq(:none)),
      "#{raw.inspect} is not a tier-1 body (classified #{classification})"

      expect(tier1_constructs(raw)).to eq(engine_constructs(raw)),
      "constructs diverged for #{raw.inspect}"
    end
  end
end
