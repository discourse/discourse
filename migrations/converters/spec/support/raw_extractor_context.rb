# frozen_string_literal: true

RSpec.shared_context "with raw extractor" do
  subject(:extractor) { described_class.new(embeds: buffer, mention_names:) }

  # The extractor defers a mention only when the source has that name, so the
  # names a spec mentions have to exist. Override for a spec about the gate
  # itself.
  let(:mention_names) do
    Migrations::SortedStringSet.new(
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

  let(:link_target) { Migrations::Database::IntermediateDB::Enums::LinkTarget }
  let(:hashtag_type) { Migrations::Database::IntermediateDB::Enums::HashtagType }
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }

  let(:buffer) do
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  end

  def extract(raw, topic_id: nil)
    extractor.extract(raw, topic_id:)
  end
end
