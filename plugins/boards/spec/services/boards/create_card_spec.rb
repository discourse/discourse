# frozen_string_literal: true

RSpec.describe Boards::CreateCard do
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
    fab!(:category)
    fab!(:tag)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:board) do
      board = Boards::Board.create!(name: "Board", slug: "board", created_by_id: admin.id)
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
    fab!(:column) { board.columns.create!(title: "To Do", position: 0) }
    fab!(:recency_column) do
      board.columns.create!(title: "Recent", position: 1, default_sort: "recency")
    end

    let(:dependencies) { { guardian: writer.guardian } }

    before do
      enable_current_plugin
      write_group.add(writer)
      write_group.add(admin)
      read_group.add(reader)
    end

    context "when creating a floater card" do
      let(:params) { { board_id: board.id, column_id: column.id, title: "New Task" } }

      it { is_expected.to run_successfully }

      it "creates a floater card" do
        card = result[:card]
        expect(card.card_type).to eq("floater")
        expect(card.title).to eq("New Task")
        expect(card.column_id).to eq(column.id)
        expect(card.column_changed_at).to be_present
        expect(card.created_by_id).to eq(writer.id)
      end

      it "creates a card history record" do
        expect { result }.to change { Boards::CardHistory.where(action: :card_created).count }.by(1)
        expect(Boards::CardHistory.where(action: :card_created).last).to have_attributes(
          acting_user_id: writer.id,
          board_id: board.id,
        )
      end
    end

    context "when creating a floater card with a URL-only title" do
      let(:url) { "https://github.com/discourse/discourse/pull/42462" }
      let(:params) { { board_id: board.id, column_id: column.id, title: url } }

      it "creates the card without resolving the onebox inline" do
        Boards::Action::CardInlineOnebox.expects(:call).never

        expect(result[:card].inline_onebox_data).to be_nil
      end
    end

    context "when creating a floater card in a column sorted by recency" do
      let(:params) { { board_id: board.id, column_id: recency_column.id, title: "Recent Task" } }

      before do
        board.cards.create!(
          card_type: :floater,
          title: "Existing",
          column_id: recency_column.id,
          position: 0,
          created_by_id: admin.id,
        )
      end

      it "places it at the beginning" do
        expect(result[:card].position).to be < 0
        expect(result[:card].column_changed_at).to be_present
      end
    end

    context "when creating a floater card with tag ids" do
      let(:params) do
        { board_id: board.id, column_id: column.id, title: "Tagged", tag_ids: [tag.id] }
      end

      it { is_expected.to run_successfully }

      it "persists tag ids" do
        expect(result[:card].tag_ids).to eq([tag.id])
      end
    end

    context "when creating a floater card with a hidden tag id" do
      fab!(:hidden_tag, :tag) { Fabricate(:tag, name: "staff-boards") }

      let(:params) do
        { board_id: board.id, column_id: column.id, title: "Tagged", tag_ids: [hidden_tag.id] }
      end

      before { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

      it "raises InvalidParameters" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when creating a floater card in a tagged column" do
      fab!(:column_tag, :tag) { Fabricate(:tag, name: "column-tag") }
      fab!(:sibling_tag, :tag) { Fabricate(:tag, name: "sibling-tag") }
      fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated-tag") }
      fab!(:tagged_column) do
        board.columns.create!(title: "Tagged", position: 3, tag_id: column_tag.id)
      end

      let(:params) do
        {
          board_id: board.id,
          column_id: tagged_column.id,
          title: "Tagged floater",
          tag_ids: [sibling_tag.id, unrelated_tag.id],
        }
      end

      before { board.columns.create!(title: "Sibling", position: 4, tag_id: sibling_tag.id) }

      it "applies the column tag using the column tag resolution rules" do
        expect(result[:card].tag_ids).to contain_exactly(column_tag.id, unrelated_tag.id)
      end
    end

    context "when creating a topic card" do
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: topic.id } }
      let(:dependencies) { { guardian: admin.guardian } }

      it { is_expected.to run_successfully }

      it "creates a topic card" do
        card = result[:card]
        expect(card.card_type).to eq("topic")
        expect(card.topic_id).to eq(topic.id)
        expect(card.column_id).to eq(column.id)
      end
    end

    context "when board is not found" do
      let(:params) { { board_id: 0, column_id: column.id, title: "Test" } }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when column is not found" do
      let(:params) { { board_id: board.id, column_id: 0, title: "Test" } }

      it { is_expected.to fail_to_find_a_model(:column) }
    end

    context "when user cannot write" do
      let(:params) { { board_id: board.id, column_id: column.id, title: "Test" } }
      let(:dependencies) { { guardian: reader.guardian } }

      it { is_expected.to fail_a_policy(:can_write) }
    end

    context "when topic does not exist" do
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: -1 } }
      let(:dependencies) { { guardian: admin.guardian } }

      it "raises NotFound" do
        expect { result }.to raise_error(Discourse::NotFound)
      end
    end

    context "when user cannot see the topic" do
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }
      let(:params) { { board_id: board.id, column_id: column.id, topic_id: private_topic.id } }

      it "raises NotFound" do
        expect { result }.to raise_error(Discourse::NotFound)
      end
    end

    context "when creating a card for a category definition topic" do
      fab!(:category_with_def, :category_with_definition)
      let(:params) do
        { board_id: board.id, column_id: column.id, topic_id: category_with_def.topic_id }
      end
      let(:dependencies) { { guardian: admin.guardian } }

      it "raises an error" do
        expect { result }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end
end
