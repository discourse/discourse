# frozen_string_literal: true

RSpec.describe Boards::ColumnsReplacer do
  fab!(:admin)
  fab!(:board) { Boards::Board.create!(name: "Test", slug: "test", created_by_id: admin.id) }

  before { enable_current_plugin }

  describe ".replace!" do
    it "creates new columns from payload" do
      Boards::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "title" => "Backlog" }, { "title" => "Done", "icon" => "check" }],
        user: admin,
      )

      columns = board.columns.order(:position)
      expect(columns.count).to eq(2)
      expect(columns.first.title).to eq("Backlog")
      expect(columns.first.position).to eq(0)
      expect(columns.last.title).to eq("Done")
      expect(columns.last.icon).to eq("check")
      expect(columns.last.default_sort).to eq("priority")
      expect(columns.last.position).to eq(1)
    end

    it "updates existing columns by id" do
      col = board.columns.create!(title: "Old", position: 0)

      Boards::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "id" => col.id, "title" => "New" }],
        user: admin,
      )

      expect(col.reload.title).to eq("New")
    end

    it "removes columns not in the payload" do
      col1 = board.columns.create!(title: "Keep", position: 0)
      col2 = board.columns.create!(title: "Remove", position: 1)

      Boards::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "id" => col1.id, "title" => "Keep" }],
        user: admin,
      )

      expect(board.columns.reload.pluck(:id)).to contain_exactly(col1.id)
      expect(Boards::Column.find_by(id: col2.id)).to be_nil
    end

    it "deletes floater cards in removed columns" do
      col = board.columns.create!(title: "Gone", position: 0)
      board.cards.create!(
        card_type: :floater,
        title: "Floater",
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      Boards::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      expect(board.cards.reload.count).to eq(0)
    end

    it "deletes topic cards in removed columns" do
      topic = Fabricate(:topic)
      col = board.columns.create!(title: "Gone", position: 0)
      card =
        board
          .cards
          .find_or_initialize_by(topic_id: topic.id)
          .tap do |c|
            c.assign_attributes(
              card_type: :topic,
              column_id: col.id,
              position: 0,
              created_by_id: admin.id,
            )
            c.save!
          end

      Boards::ColumnsReplacer.replace!(board:, columns_payload: [], user: admin)

      expect(Boards::Card.find_by(id: card.id)).to be_nil
    end

    it "persists default sort" do
      Boards::ColumnsReplacer.replace!(
        board:,
        columns_payload: [{ "title" => "Recent", "default_sort" => "recency" }],
        user: admin,
      )

      expect(board.columns.last.default_sort).to eq("recency")
    end

    it "rejects invalid default sort" do
      expect {
        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Broken", "default_sort" => "random" }],
          user: admin,
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    describe "when a tag is provided" do
      fab!(:tag)

      it "creates a new column with the tag" do
        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Backlog", "tag_name" => tag.name }],
          user: admin,
        )

        expect(board.columns.last.tag).to eq(tag)
      end

      it "creates the tag when it doesn't exist and the user can create tags" do
        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "title" => "Backlog", "tag_name" => "brand-new" }],
          user: admin,
        )

        expect(board.columns.last.tag.name).to eq("brand-new")
      end

      it "raises an error if the tag is not found and the user cannot create tags" do
        user = Fabricate(:user)
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:staff]

        expect {
          Boards::ColumnsReplacer.replace!(
            board:,
            columns_payload: [{ "title" => "Backlog", "tag_name" => "unknown" }],
            user: user,
          )
        }.to raise_error(
          Discourse::InvalidParameters,
          I18n.t("boards.errors.unknown_tag_name", tag_name: "unknown"),
        )
      end

      it "raises an error if a tag has already been used for another column" do
        expect {
          Boards::ColumnsReplacer.replace!(
            board:,
            columns_payload: [
              { "title" => "Backlog", "tag_name" => tag.name },
              { "title" => "Done", "tag_name" => tag.name },
            ],
            user: admin,
          )
        }.to raise_error(
          Discourse::InvalidParameters,
          I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name),
        )
      end

      it "applies a new column tag to existing floater cards" do
        column = board.columns.create!(title: "Backlog", position: 0)
        unrelated_tag = Fabricate(:tag, name: "unrelated")
        card =
          board.cards.create!(
            card_type: :floater,
            title: "Existing floater",
            tag_ids: [unrelated_tag.id],
            column_id: column.id,
            position: 0,
            created_by_id: admin.id,
          )

        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "id" => column.id, "title" => "Backlog", "tag_name" => tag.name }],
          user: admin,
        )

        expect(card.reload.tag_ids).to contain_exactly(tag.id, unrelated_tag.id)
      end

      it "replaces a changed column tag on existing floater cards" do
        old_tag = Fabricate(:tag, name: "old-column")
        new_tag = Fabricate(:tag, name: "new-column")
        column = board.columns.create!(title: "Doing", position: 0, tag_id: old_tag.id)
        unrelated_tag = Fabricate(:tag, name: "preserved")
        card =
          board.cards.create!(
            card_type: :floater,
            title: "Existing floater",
            tag_ids: [old_tag.id, unrelated_tag.id],
            column_id: column.id,
            position: 0,
            created_by_id: admin.id,
          )

        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [{ "id" => column.id, "title" => "Doing", "tag_name" => new_tag.name }],
          user: admin,
        )

        expect(card.reload.tag_ids).to contain_exactly(new_tag.id, unrelated_tag.id)
      end

      it "normalizes floater cards in other columns when a new column tag is assigned" do
        todo_tag = Fabricate(:tag, name: "todo")
        blocked_tag = Fabricate(:tag, name: "blocked")
        column = board.columns.create!(title: "Todo", position: 0, tag_id: todo_tag.id)
        blocked_column = board.columns.create!(title: "Blocked", position: 1)
        card =
          board.cards.create!(
            card_type: :floater,
            title: "Existing floater",
            tag_ids: [todo_tag.id, blocked_tag.id],
            column_id: column.id,
            position: 0,
            created_by_id: admin.id,
          )

        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [
            { "id" => column.id, "title" => "Todo", "tag_name" => todo_tag.name },
            { "id" => blocked_column.id, "title" => "Blocked", "tag_name" => blocked_tag.name },
          ],
          user: admin,
        )

        expect(card.reload.tag_ids).to contain_exactly(todo_tag.id)
      end

      it "rolls back column changes when loose-card tag enforcement fails" do
        column = board.columns.create!(title: "Doing", position: 0)
        allow(Boards::LooseCardTagMutator).to receive(:apply_to_column!).and_raise(
          ActiveRecord::RecordInvalid,
        )

        expect {
          Boards::ColumnsReplacer.replace!(
            board:,
            columns_payload: [{ "id" => column.id, "title" => "Doing", "tag_name" => tag.name }],
            user: admin,
          )
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(column.reload.tag_id).to be_nil
      end

      it "removes board column tags when a column tag is removed" do
        old_tag = Fabricate(:tag, name: "old-column")
        sibling_tag = Fabricate(:tag, name: "sibling-column")
        unrelated_tag = Fabricate(:tag, name: "preserved")
        column = board.columns.create!(title: "Doing", position: 0, tag_id: old_tag.id)
        sibling_column =
          board.columns.create!(title: "Sibling", position: 1, tag_id: sibling_tag.id)
        card =
          board.cards.create!(
            card_type: :floater,
            title: "Existing floater",
            tag_ids: [old_tag.id, sibling_tag.id, unrelated_tag.id],
            column_id: column.id,
            position: 0,
            created_by_id: admin.id,
          )

        Boards::ColumnsReplacer.replace!(
          board:,
          columns_payload: [
            { "id" => column.id, "title" => "Doing" },
            { "id" => sibling_column.id, "title" => "Sibling", "tag_name" => sibling_tag.name },
          ],
          user: admin,
        )

        expect(card.reload.tag_ids).to contain_exactly(unrelated_tag.id)
      end
    end
  end
end
