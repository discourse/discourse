# frozen_string_literal: true

RSpec.describe Boards::Card do
  fab!(:admin)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category) }

  before { enable_current_plugin }

  fab!(:board) { Boards::Board.create!(name: "Test", slug: "test-card", created_by_id: admin.id) }
  fab!(:column) { board.columns.create!(title: "Col", position: 0) }

  describe "validations" do
    it "is valid as a floater with title and column" do
      card =
        board.cards.build(
          card_type: :floater,
          title: "A task",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).to be_valid
    end

    it "is valid as a topic card with topic and column" do
      card =
        board.cards.build(
          card_type: :topic,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).to be_valid
    end

    it "requires title for floater cards" do
      card =
        board.cards.build(
          card_type: :floater,
          title: nil,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:title]).to include("can't be blank")
    end

    it "requires topic_id for topic cards" do
      card =
        board.cards.build(
          card_type: :topic,
          topic_id: nil,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:topic_id]).to include("can't be blank")
    end

    it "normalizes card_type to topic when topic_id is present" do
      card =
        board.cards.build(
          card_type: :floater,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("topic")
    end

    it "requires column_id for floater cards" do
      card =
        board.cards.build(
          card_type: :floater,
          title: "Orphan",
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:column_id]).to include("can't be blank")
    end

    it "requires column_id for topic cards" do
      card =
        board.cards.build(
          card_type: :topic,
          topic_id: topic.id,
          column_id: nil,
          position: 0,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:column_id]).to include("can't be blank")
    end

    it "requires position" do
      card =
        board.cards.build(
          card_type: :floater,
          title: "No position",
          column_id: column.id,
          position: nil,
          created_by_id: admin.id,
        )
      expect(card).not_to be_valid
      expect(card.errors[:position]).to include("can't be blank")
    end
  end

  describe "normalize_card_type" do
    it "auto-sets card_type to topic when topic_id is present" do
      card =
        board.cards.build(
          card_type: :floater,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("topic")
    end

    it "does not change card_type when topic_id is blank" do
      card =
        board.cards.build(
          card_type: :floater,
          title: "Floater",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      card.valid?
      expect(card.card_type).to eq("floater")
    end
  end

  describe "scopes" do
    it ".with_column returns only cards with a column" do
      in_col =
        board.cards.create!(
          card_type: :floater,
          title: "In column",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )

      expect(described_class.with_column.pluck(:id)).to eq([in_col.id])
    end

    it ".ordered sorts by position then id" do
      card_b =
        board.cards.create!(
          card_type: :floater,
          title: "B",
          column_id: column.id,
          position: 1,
          created_by_id: admin.id,
        )
      card_a =
        board.cards.create!(
          card_type: :floater,
          title: "A",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )

      expect(described_class.ordered.pluck(:id)).to eq([card_a.id, card_b.id])
    end
  end

  describe ".normalize_tag_ids!" do
    it "rejects malformed tag ids" do
      expect { described_class.normalize_tag_ids!(["#{tag.id}abc"]) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe ".ordered_tags" do
    it "omits missing tags" do
      expect(described_class.ordered_tags([tag.id, tag.id + 1000])).to eq([tag])
    end
  end

  describe "#tags" do
    fab!(:tag_a) { Fabricate(:tag, name: "alpha") }
    fab!(:tag_b) { Fabricate(:tag, name: "beta") }

    it "returns tags ordered by name" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "T",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
          tag_ids: [tag_b.id, tag_a.id],
        )

      expect(card.tags).to eq([tag_a, tag_b])
    end

    it "memoizes the result" do
      card =
        board.cards.create!(
          card_type: :floater,
          title: "T",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
          tag_ids: [tag_a.id],
        )
      card.tags

      queries = track_sql_queries { 5.times { card.tags } }
      expect(queries).to be_empty
    end
  end

  describe ".preload_tags" do
    fab!(:tag_a) { Fabricate(:tag, name: "alpha") }
    fab!(:tag_b) { Fabricate(:tag, name: "beta") }

    it "loads tags for many cards in a single query" do
      card_a =
        board.cards.create!(
          card_type: :floater,
          title: "A",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
          tag_ids: [tag_a.id],
        )
      card_b =
        board.cards.create!(
          card_type: :floater,
          title: "B",
          column_id: column.id,
          position: 1,
          created_by_id: admin.id,
          tag_ids: [tag_a.id, tag_b.id],
        )

      cards = [card_a, card_b]
      described_class.preload_tags(cards)

      queries = track_sql_queries { cards.each(&:tags) }
      expect(queries).to be_empty
      expect(card_a.tags).to eq([tag_a])
      expect(card_b.tags).to eq([tag_a, tag_b])
    end

    it "handles empty input and cards without tags" do
      expect(described_class.preload_tags([])).to eq([])

      card =
        board.cards.create!(
          card_type: :floater,
          title: "T",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      described_class.preload_tags([card])

      expect(card.tags).to eq([])
    end
  end

  describe "#recency_at" do
    it "uses the later of topic bumped_at and column_changed_at for topic cards" do
      bumped_at = 2.days.ago
      column_changed_at = 1.day.ago
      topic.update_columns(bumped_at: bumped_at)
      card =
        board.cards.create!(
          card_type: :topic,
          topic_id: topic.id,
          column_id: column.id,
          position: 0,
          column_changed_at: column_changed_at,
          created_by_id: admin.id,
        )

      expect(card.reload.recency_at.to_i).to eq(column_changed_at.to_i)
    end

    it "uses the later of updated_at and column_changed_at for floater cards" do
      column_changed_at = 3.days.ago
      updated_at = 2.hours.ago
      card =
        board.cards.create!(
          card_type: :floater,
          title: "Recent floater",
          column_id: column.id,
          position: 0,
          column_changed_at: column_changed_at,
          created_by_id: admin.id,
        )
      card.update_columns(updated_at: updated_at)

      expect(card.reload.recency_at.to_i).to eq(updated_at.to_i)
    end
  end
end
