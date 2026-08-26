# frozen_string_literal: true

RSpec.shared_context "with raw extractor" do
  subject(:extractor) { described_class.new(embeds: buffer, mention_names:, hashtag_names:) }

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
  let(:hashtag_names) do
    Migrations::CompactStringSet.new(
      %w[announcements general news release reply support support:billing team v2.0].map do |name|
        Migrations::NameNormalizer.normalize(name)
      end,
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
