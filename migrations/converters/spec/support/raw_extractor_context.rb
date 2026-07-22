# frozen_string_literal: true

RSpec.shared_context "with raw extractor" do
  subject(:extractor) { described_class.new(embeds: buffer) }

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
