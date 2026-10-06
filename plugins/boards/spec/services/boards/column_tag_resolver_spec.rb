# frozen_string_literal: true

RSpec.describe Boards::ColumnTagResolver do
  fab!(:admin)
  fab!(:todo_tag, :tag) { Fabricate(:tag, name: "todo") }
  fab!(:doing_tag, :tag) { Fabricate(:tag, name: "doing") }
  fab!(:done_tag, :tag) { Fabricate(:tag, name: "done") }
  fab!(:unrelated_tag, :tag) { Fabricate(:tag, name: "unrelated") }
  fab!(:board) do
    Boards::Board.create!(name: "Board", slug: "resolver-board", created_by_id: admin.id)
  end
  fab!(:todo_column) { board.columns.create!(title: "Todo", position: 0, tag_id: todo_tag.id) }
  fab!(:doing_column) { board.columns.create!(title: "Doing", position: 1, tag_id: doing_tag.id) }
  fab!(:backlog_column) { board.columns.create!(title: "Backlog", position: 2) }

  before { enable_current_plugin }

  describe ".resolve_tag_ids" do
    it "adds the target column tag and removes sibling column tags" do
      resolved_tag_ids =
        described_class.resolve_tag_ids(
          current_tag_ids: [todo_tag.id, unrelated_tag.id],
          column: doing_column,
        )

      expect(resolved_tag_ids).to contain_exactly(doing_tag.id, unrelated_tag.id)
    end

    it "removes all board column tags when resolving to an untagged column" do
      resolved_tag_ids =
        described_class.resolve_tag_ids(
          current_tag_ids: [todo_tag.id, doing_tag.id, unrelated_tag.id],
          column: backlog_column,
        )

      expect(resolved_tag_ids).to contain_exactly(unrelated_tag.id)
    end

    it "preserves a target column tag already present on the card" do
      resolved_tag_ids =
        described_class.resolve_tag_ids(
          current_tag_ids: [doing_tag.id, unrelated_tag.id],
          column: doing_column,
        )

      expect(resolved_tag_ids).to contain_exactly(doing_tag.id, unrelated_tag.id)
    end

    it "normalizes duplicate and string tag ids" do
      resolved_tag_ids =
        described_class.resolve_tag_ids(
          current_tag_ids: [todo_tag.id.to_s, todo_tag.id, unrelated_tag.id.to_s],
          column: doing_column,
        )

      expect(resolved_tag_ids).to contain_exactly(doing_tag.id, unrelated_tag.id)
    end

    it "does not add a stale target column tag" do
      stale_tag_id = done_tag.id
      done_tag.destroy!
      doing_column.update_column(:tag_id, stale_tag_id)

      resolved_tag_ids =
        described_class.resolve_tag_ids(current_tag_ids: [unrelated_tag.id], column: doing_column)

      expect(resolved_tag_ids).to contain_exactly(unrelated_tag.id)
    end

    it "ignores stale board column tags when resolving sibling tags" do
      stale_tag_id = done_tag.id
      done_tag.destroy!
      board.columns.create!(title: "Stale", position: 3, tag_id: stale_tag_id)

      resolved_tag_ids =
        described_class.resolve_tag_ids(
          current_tag_ids: [doing_tag.id, unrelated_tag.id],
          column: todo_column,
        )

      expect(resolved_tag_ids).to contain_exactly(todo_tag.id, unrelated_tag.id)
    end
  end
end
