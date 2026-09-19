# frozen_string_literal: true

describe "Board Category Constraints" do
  fab!(:current_user, :admin)
  fab!(:board) { Fabricate(:boards_board, column_names: ["To Do", "In Progress", "Done"]) }

  let(:board_viewer) { PageObjects::Pages::BoardsBoardViewer.new }
  let(:board_component) { PageObjects::Components::BoardsBoard.new }
  let(:board_manage_page) { PageObjects::Pages::BoardsManageBoards.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    sign_in(current_user)
  end

  context "when a board has a single category constraint" do
    fab!(:category)
    fab!(:topic) { Fabricate(:topic_with_op, category: category) }
    fab!(:topic_2, :topic) { Fabricate(:topic_with_op) }

    before do
      board.update!(category_ids: [category.id])
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(topic_2, force: true)
    end

    after { SearchIndexer.disable }

    it "allows topics in the category to be added to the board" do
      board_viewer.visit_board(board)
      board_viewer.click_add_topic_as_card("To Do")
      board_viewer.fill_topic_search(topic.title)
      board_viewer.select_topic_search_result(topic.id)

      expect(board_viewer).to have_card_in_column("To Do", topic.title)
    end

    it "prompts to move the topic to the correct constraint category if it's not in the category" do
      board_viewer.visit_board(board)
      board_viewer.click_add_topic_as_card("To Do")
      board_viewer.fill_topic_search(topic_2.title)
      board_viewer.select_topic_search_result(topic_2.id)

      expect(board_viewer).to have_constraint_fix_modal

      board_viewer.click_constraint_fix_category(category.id)
      board_viewer.click_constraint_fix_confirm

      expect(board_viewer).to have_card_in_column("To Do", topic_2.title)
      expect(topic_2.reload.category_id).to eq(category.id)
    end

    describe "adding a column to the board" do
      fab!(:tag_group) { Fabricate(:tag_group, name: "Support Tags") }
      fab!(:tag) { Fabricate(:tag, name: "support") }
      fab!(:tag_group_membership) { TagGroupMembership.create!(tag: tag, tag_group: tag_group) }

      before { category.update!(tag_groups: [tag_group]) }

      it "allows tags in tag groups restricted to the category to be used for the column" do
        board_viewer.visit_board(board)
        board_component.open_board_menu
        board_component.click_add_column_menu_item
        board_manage_page.select_modal_column_tag(tag.name)
        board_manage_page.save_column_modal

        expect(board_viewer).to have_column(tag.name)
      end
    end
  end
end
