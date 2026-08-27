# frozen_string_literal: true

RSpec.shared_context "with raw extractor" do
  subject(:extractor) do
    described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:)
  end

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
end
