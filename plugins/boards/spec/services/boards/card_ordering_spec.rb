# frozen_string_literal: true

RSpec.describe Boards::CardOrdering do
  fab!(:admin)

  before { enable_current_plugin }

  fab!(:board) do
    Boards::Board.create!(name: "Test", slug: "test-ordering", created_by_id: admin.id)
  end
  fab!(:column) { board.columns.create!(title: "Col A", position: 0) }
  fab!(:recency_column) do
    board.columns.create!(title: "Recent", position: 1, default_sort: "recency")
  end

  let(:gap) { described_class::GAP_SIZE }

  def create_card(title:, position:, column: nil)
    board.cards.create!(
      card_type: :floater,
      title: title,
      column_id: (column || self.column).id,
      position: position,
      created_by_id: admin.id,
    )
  end

  describe ".place_card!" do
    it "places a card at the end when no after_card_id given" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: gap)
      new_card = create_card(title: "New", position: 99 * gap)

      described_class.place_card!(new_card, column: column)

      expect(new_card.reload.position).to be > card2.reload.position
      expect(card1.reload.position).to be < card2.position
    end

    it "places a card after the specified card" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: gap)
      card3 = create_card(title: "Third", position: 2 * gap)

      described_class.place_card!(card3, column: column, after_card_id: card1.id)

      expect(card3.reload.position).to be > card1.reload.position
      expect(card3.position).to be < card2.reload.position
    end

    it "places a card at position 0 when after_card_id is absent and column is empty" do
      new_card = create_card(title: "Solo", position: 5 * gap)

      described_class.place_card!(new_card, column: column)

      expect(new_card.reload.position).to eq(0)
    end

    it "moves a card from one column to another" do
      col_b = board.columns.create!(title: "Col B", position: 1)
      card = create_card(title: "Mover", position: 0)
      target_card = create_card(title: "Target", position: 0, column: col_b)

      described_class.place_card!(card, column: col_b, after_card_id: target_card.id)

      expect(card.reload.column_id).to eq(col_b.id)
      expect(card.position).to be > target_card.reload.position
    end

    it "reorders within the same column" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: gap)
      card3 = create_card(title: "Third", position: 2 * gap)

      described_class.place_card!(card1, column: column, after_card_id: card2.id)

      expect(card1.reload.position).to be > card2.reload.position
      expect(card1.position).to be < card3.reload.position
    end

    it "excludes the card itself from siblings during reorder" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: gap)

      described_class.place_card!(card2, column: column, after_card_id: card1.id)

      expect(card1.reload.position).to be < card2.reload.position
    end

    it "handles invalid after_card_id by appending to end" do
      card1 = create_card(title: "First", position: 0)
      new_card = create_card(title: "New", position: 5 * gap)

      described_class.place_card!(new_card, column: column, after_card_id: -999)

      expect(new_card.reload.position).to be > card1.reload.position
    end

    it "places a card at position_first when position_first is true" do
      card1 = create_card(title: "First", position: 0)
      card2 = create_card(title: "Second", position: gap)
      new_card = create_card(title: "New", position: 99 * gap)

      described_class.place_card!(new_card, column: column, position_first: true)

      expect(new_card.reload.position).to be < card1.reload.position
      expect(card1.position).to be < card2.reload.position
    end

    it "handles gap exhaustion by rebalancing" do
      card1 = create_card(title: "First", position: 1000)
      card2 = create_card(title: "Second", position: 1001)
      new_card = create_card(title: "Squeeze", position: 99 * gap)

      described_class.place_card!(new_card, column: column, after_card_id: card1.id)

      expect(new_card.reload.position).to be > card1.reload.position
      expect(new_card.position).to be < card2.reload.position
    end

    it "supports negative positions from repeated insert-at-beginning" do
      card1 = create_card(title: "First", position: 0)

      new_card1 = create_card(title: "Before1", position: 99 * gap)
      described_class.place_card!(new_card1, column: column, position_first: true)
      expect(new_card1.reload.position).to be < card1.reload.position

      new_card2 = create_card(title: "Before2", position: 99 * gap)
      described_class.place_card!(new_card2, column: column, position_first: true)
      expect(new_card2.reload.position).to be < new_card1.reload.position
    end

    it "moves cards into column sorted by recency at the beginning and stamps column_changed_at" do
      existing = create_card(title: "Existing", position: 0, column: recency_column)
      card = create_card(title: "Mover", position: gap, column: column)
      previous_changed_at = 2.days.ago
      card.update_column(:column_changed_at, previous_changed_at)

      freeze_time do
        described_class.place_card!(card, column: recency_column, after_card_id: existing.id)

        card.reload
        expect(card.column_id).to eq(recency_column.id)
        expect(card.position).to be < existing.reload.position
        expect(card.column_changed_at.to_i).to eq(Time.zone.now.to_i)
        expect(card.column_changed_at.to_i).not_to eq(previous_changed_at.to_i)
      end
    end

    it "rejects manual reordering inside column sorted by recency" do
      card = create_card(title: "First", position: 0, column: recency_column)
      other = create_card(title: "Second", position: gap, column: recency_column)

      expect do
        described_class.place_card!(card, column: recency_column, after_card_id: other.id)
      end.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe ".append_to_column!" do
    it "sets position after the last card in the column" do
      create_card(title: "First", position: 0)
      create_card(title: "Second", position: gap)
      new_card = board.cards.build(card_type: :floater, title: "Appended", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card.column_id).to eq(column.id)
      expect(new_card.position).to eq(2 * gap)
    end

    it "sets position to GAP_SIZE for an empty column" do
      new_card = board.cards.build(card_type: :floater, title: "First", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card.position).to eq(gap)
    end

    it "does not persist the card" do
      new_card = board.cards.build(card_type: :floater, title: "Unsaved", created_by_id: admin.id)

      described_class.append_to_column!(new_card, column)

      expect(new_card).to be_new_record
    end

    it "prepends new cards in column sorted by recency" do
      existing = create_card(title: "Existing", position: 0, column: recency_column)
      new_card = board.cards.build(card_type: :floater, title: "Recent", created_by_id: admin.id)

      freeze_time do
        described_class.append_to_column!(new_card, recency_column)

        expect(new_card.column_id).to eq(recency_column.id)
        expect(new_card.position).to be < existing.position
        expect(new_card.column_changed_at.to_i).to eq(Time.zone.now.to_i)
      end
    end
  end
end
