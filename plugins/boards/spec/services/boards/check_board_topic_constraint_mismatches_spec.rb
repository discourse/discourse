# frozen_string_literal: true

RSpec.describe Boards::CheckBoardTopicConstraintMismatches do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:target_column_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:write_group, :group)
    fab!(:category)
    fab!(:other_category, :category)
    fab!(:third_category, :category)
    fab!(:board_tag, :tag) { Fabricate(:tag, name: "board-filter") }
    fab!(:other_board_tag, :tag) { Fabricate(:tag, name: "other-board-filter") }
    fab!(:sibling_tag, :tag) { Fabricate(:tag, name: "sibling-column") }
    fab!(:target_tag, :tag) { Fabricate(:tag, name: "target-column") }
    fab!(:topic) { Fabricate(:topic, category:) }
    fab!(:board) do
      Fabricate(:boards_board, created_by: acting_user, additional_manage_groups: [write_group])
    end
    fab!(:sibling_column) { Fabricate(:boards_column, board:, tag: sibling_tag) }
    fab!(:target_column) { Fabricate(:boards_column, board:) }

    let(:params) { { id: board.id, topic_id: topic.id, target_column_id: target_column.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { enable_current_plugin }

    context "when the contract is invalid" do
      let(:params) { { id: board.id, topic_id: topic.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the board is not found" do
      let(:params) { super().merge(id: 0) }

      it { is_expected.to fail_to_find_a_model(:board) }
    end

    context "when the user cannot edit the board" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_board) }
    end

    context "when the topic is not found" do
      let(:params) { super().merge(topic_id: 0) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic is not visible to the user" do
      fab!(:acting_user, :user)
      fab!(:private_group, :group)
      fab!(:private_category) { Fabricate(:private_category, group: private_group) }
      fab!(:topic) { Fabricate(:topic, category: private_category) }

      before { write_group.add(acting_user) }

      it { is_expected.to fail_a_policy(:can_view_topic) }
    end

    context "when the target column is not found" do
      let(:params) { super().merge(target_column_id: 0) }

      it { is_expected.to fail_to_find_a_model(:target_column) }
    end

    context "when the target column belongs to another board" do
      fab!(:other_board, :boards_board)
      fab!(:other_board_column) { Fabricate(:boards_column, board: other_board) }

      let(:params) { super().merge(target_column_id: other_board_column.id) }

      it { is_expected.to fail_to_find_a_model(:target_column) }
    end

    context "without board constraints" do
      it { is_expected.to run_successfully }

      it "returns no required constraint fixes" do
        expect(result[:categories_needed]).to be_empty
        expect(result[:tags_needed]).to be_empty
      end
    end

    context "with category constraints" do
      context "when the topic's current category matches" do
        before { board.update!(category_ids: [category.id]) }

        it { is_expected.to run_successfully }

        it "returns no categories" do
          expect(result[:categories_needed]).to be_empty
        end
      end

      context "when the topic's current category does not match" do
        before { board.update!(category_ids: [other_category.id, third_category.id]) }

        it { is_expected.to run_successfully }

        it "returns every board category" do
          expect(result[:categories_needed]).to contain_exactly(
            other_category.id,
            third_category.id,
          )
        end
      end

      context "when the target column moves the topic to a matching category" do
        before do
          board.update!(category_ids: [other_category.id])
          target_column.update!(move_to_category_id: other_category.id)
        end

        it { is_expected.to run_successfully }

        it "uses the target category instead of the topic's current category" do
          expect(result[:categories_needed]).to be_empty
        end
      end

      context "when the target column moves a matching topic to a nonmatching category" do
        before do
          board.update!(category_ids: [category.id])
          target_column.update!(move_to_category_id: other_category.id)
        end

        it { is_expected.to run_successfully }

        it "returns every board category" do
          expect(result[:categories_needed]).to eq([category.id])
        end
      end
    end

    context "with tag constraints" do
      context "when a current non-column topic tag matches" do
        fab!(:topic) { Fabricate(:topic, category:, tags: [board_tag]) }

        before { board.update!(tag_ids: [board_tag.id]) }

        it { is_expected.to run_successfully }

        it "returns no tags" do
          expect(result[:tags_needed]).to be_empty
        end
      end

      context "when no effective topic tag matches" do
        before { board.update!(tag_ids: [board_tag.id, other_board_tag.id]) }

        it { is_expected.to run_successfully }

        it "returns every board tag" do
          expect(result[:tags_needed]).to contain_exactly(board_tag.name, other_board_tag.name)
        end
      end

      context "when a board tag is not visible to the user" do
        fab!(:acting_user, :user)
        fab!(:hidden_board_tag, :tag)

        before do
          write_group.add(acting_user)
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_board_tag.name])
          board.update!(tag_ids: [board_tag.id, hidden_board_tag.id])
        end

        it { is_expected.to run_successfully }

        it "does not return the restricted tag name" do
          expect(result[:tags_needed]).to eq([board_tag.name])
        end
      end

      context "when the target column tag matches" do
        before do
          board.update!(tag_ids: [target_tag.id])
          target_column.update!(tag_id: target_tag.id)
        end

        it { is_expected.to run_successfully }

        it "includes the target column tag in the effective tags" do
          expect(result[:tags_needed]).to be_empty
        end
      end

      context "when only a sibling column tag matches" do
        fab!(:topic) { Fabricate(:topic, category:, tags: [sibling_tag]) }

        before do
          board.update!(tag_ids: [sibling_tag.id])
          target_column.update!(tag_id: target_tag.id)
        end

        it { is_expected.to run_successfully }

        it "returns the removed sibling tag" do
          expect(result[:tags_needed]).to eq([sibling_tag.name])
        end
      end

      context "when an unrelated board tag remains after sibling tag removal" do
        fab!(:topic) { Fabricate(:topic, category:, tags: [sibling_tag, board_tag]) }

        before do
          board.update!(tag_ids: [board_tag.id])
          target_column.update!(tag_id: target_tag.id)
        end

        it { is_expected.to run_successfully }

        it "returns no tags" do
          expect(result[:tags_needed]).to be_empty
        end
      end

      context "when an untagged target removes every column tag" do
        fab!(:topic) { Fabricate(:topic, category:, tags: [sibling_tag]) }

        before { board.update!(tag_ids: [sibling_tag.id]) }

        it { is_expected.to run_successfully }

        it "returns the removed column tag" do
          expect(result[:tags_needed]).to eq([sibling_tag.name])
        end
      end
    end

    context "with category and tag constraints" do
      before { board.update!(category_ids: [other_category.id], tag_ids: [board_tag.id]) }

      it { is_expected.to run_successfully }

      it "returns both required constraint fixes" do
        expect(result[:categories_needed]).to eq([other_category.id])
        expect(result[:tags_needed]).to eq([board_tag.name])
      end
    end
  end
end
