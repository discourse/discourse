# frozen_string_literal: true

RSpec.describe Boards::ClearColumn do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:board_id) }
    it { is_expected.to validate_presence_of(:column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:writer, :user)
    fab!(:reader, :user)
    fab!(:write_group, :group)
    fab!(:read_group, :group)
    fab!(:category) { Fabricate(:category, name: "Boards") }
    fab!(:topic1) { Fabricate(:topic, category: category) }
    fab!(:topic2) { Fabricate(:topic, category: category) }
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board-cc", created_by_id: admin.id)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board
    end
    fab!(:column) { board.columns.create!(title: "Col", position: 0) }
    fab!(:other_column) { board.columns.create!(title: "Other", position: 1) }

    let(:dependencies) { { guardian: writer.guardian } }
    let(:params) { { board_id: board.id, column_id: column.id } }

    before do
      enable_current_plugin
      write_group.add(writer)
      read_group.add(reader)
    end

    context "with a mix of floater and topic cards" do
      let!(:floater1) do
        board.cards.create!(
          card_type: :floater,
          title: "Floater 1",
          column_id: column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end
      let!(:floater2) do
        board.cards.create!(
          card_type: :floater,
          title: "Floater 2",
          column_id: column.id,
          position: 1,
          created_by_id: admin.id,
        )
      end
      let!(:topic_card1) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic1.id,
          column_id: column.id,
          position: 2,
          created_by_id: admin.id,
        )
      end
      let!(:topic_card2) do
        board.cards.create!(
          card_type: :topic,
          topic_id: topic2.id,
          column_id: column.id,
          position: 3,
          created_by_id: admin.id,
        )
      end
      let!(:other_column_card) do
        board.cards.create!(
          card_type: :floater,
          title: "Other",
          column_id: other_column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      it { is_expected.to run_successfully }

      it "destroys floater cards" do
        result
        expect(Boards::Card.find_by(id: floater1.id)).to be_nil
        expect(Boards::Card.find_by(id: floater2.id)).to be_nil
      end

      it "destroys topic cards" do
        result
        expect(Boards::Card.find_by(id: topic_card1.id)).to be_nil
        expect(Boards::Card.find_by(id: topic_card2.id)).to be_nil
      end

      it "does not affect cards in other columns" do
        result
        expect(Boards::Card.find_by(id: other_column_card.id)).to be_present
      end

      it "preserves hidden topic cards" do
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        hidden_topic = Fabricate(:topic, category: private_category)
        hidden_card =
          board.cards.create!(
            card_type: :topic,
            topic_id: hidden_topic.id,
            column_id: column.id,
            position: 4,
            created_by_id: admin.id,
          )

        result

        expect(Boards::Card.exists?(hidden_card.id)).to eq(true)
      end
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, column_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot write" do
      let(:dependencies) { { guardian: reader.guardian } }

      it { is_expected.to fail_a_policy(:can_write) }
    end
  end
end
