# frozen_string_literal: true

RSpec.shared_context "with raw extractor" do
  subject(:extractor) do
    described_class.new(
      embeds: buffer,
      mention_names:,
      hashtag_names:,
      markdown_engine:,
      custom_emoji_names:,
      internal_link_hosts:,
      internal_link_base_prefix:,
      on_foreign_host:,
      on_engine_refusal:,
    )
  end

  # Constructor arguments a spec overrides individually instead of rebuilding
  # the whole subject; the defaults mirror the constructor's own.
  let(:custom_emoji_names) { nil }
  let(:internal_link_hosts) { {} }
  let(:internal_link_base_prefix) { nil }
  let(:on_foreign_host) { nil }
  let(:on_engine_refusal) { nil }

  # The host most link specs configure as the source's own.
  let(:source_host) { "forum.example.com" }

  # A valid 40-hex upload SHA1 for upload fixtures.
  let(:sha1) { "0123456789abcdef0123456789abcdef01234567" }

  # Memoized per configuration for the whole run; specs that need different
  # engine-side names override this with another helper call.
  let(:markdown_engine) do
    MarkdownEngineHelper.context_for_names(hashtag_names: raw_hashtag_name_list)
  end

  # The extractor defers a mention only when the source has that name, so the
  # names a spec mentions have to exist. Override for a spec about the gate
  # itself.
  let(:mention_names) do
    Migrations::CompactStringSet.new(
      %w[
        admins
        alice
        all
        bob
        carol
        café_team
        channel
        gerhard
        here
        j-d
        john
        john.doe
        real
        some-user
        someuser
        staff
        user_
        José
        田中
      ].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end

  # Same for hashtags: the source has to have the category or tag. `unknown` is
  # deliberately absent — specs use it for the name that resolves to nothing.
  # The plain list also feeds the engine context's lookup sets, which decide
  # whether a `#slug` produces a token at all.
  let(:raw_hashtag_name_list) do
    %w[announcements general news release reply support support:billing team v2.0]
  end

  let(:hashtag_names) do
    Migrations::CompactStringSet.new(
      raw_hashtag_name_list.map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end

  # The intermediate DB enums, referenced through the namespace so a call site
  # names the enum it means: `enums::MentionType::USER`.
  let(:enums) { Migrations::Database::IntermediateDB::Enums }

  let(:buffer) do
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  end

  def extract(raw, topic_id: nil)
    extractor.extract(raw, topic_id:)
  end

  def link_for(raw)
    result = extract(raw)
    [buffer.links.first, result]
  end
end

# Scaffolding for the `:rails` parity batteries. They compare one construct
# against `PrettyText.cook` row by row, so each row needs its own buffer rather
# than the shared subject above.
RSpec.shared_context "with parity extractor" do
  # A battery is about one construct; the extractor requires both name sets
  # anyway, and an empty one defers nothing. A spec whose construct is gated on
  # a name overrides the set it needs.
  let(:mention_names) { Migrations::CompactStringSet.new([]) }
  let(:hashtag_names) { Migrations::CompactStringSet.new([]) }
  let(:markdown_engine) { MarkdownEngineHelper.context_for_names(hashtag_names: []) }

  def new_buffer
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  end

  def build_extractor(buffer, **overrides)
    described_class.new(
      **{ embeds: buffer, mention_names:, hashtag_names:, markdown_engine: }.merge(overrides),
    )
  end
end
