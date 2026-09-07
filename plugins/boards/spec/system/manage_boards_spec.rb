# frozen_string_literal: true

describe "Manage Boards Boards" do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:regular_user, :user)
  fab!(:manage_group, :group)
  fab!(:todo_tag, :tag) { Fabricate(:tag, name: "todo") }

  let(:boards_page) { PageObjects::Pages::BoardsManageBoards.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:permanently_delete_confirm) { PageObjects::Modals::PermanentlyDeleteConfirm.new }
  let(:access_control) { PageObjects::Components::DAccessControl.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
    manage_group.add(admin)
  end

  context "when user is in the manage group" do
    before { sign_in(manager) }

    it "warns the user when they create a board they will not be able to manage" do
      boards_page.visit_page
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Self-lockout Board")
      access_control.remove_permission_row(type: "group", id: manage_group.id)
      boards_page.save_board_modal

      expect(access_control).to have_loss_warning(
        I18n.t("access_control_list.errors.Boards::Board_user_will_lose_permission_on_create"),
      )

      access_control.confirm_loss_warning

      expect(boards_page.board_settings_modal).to be_closed
      expect(PageObjects::Components::BoardsBoard.new).to have_name("Self-lockout Board")
    end

    it "supports the full board lifecycle" do
      boards_page.visit_page
      expect(boards_page).to have_empty_state

      boards_page.click_new_board
      boards_page.fill_modal_board_name("Sprint Board")
      boards_page.toggle_modal_advanced_settings
      boards_page.board_settings_form.field("require_confirmation").toggle
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = Boards::Board.last
      expect(board.name).to eq("Sprint Board")
      expect(board.require_confirmation).to eq(true)
      expect(board.permission_acl.permission_group_ids("manage")).to contain_exactly(
        Group::AUTO_GROUPS[:admins],
        manage_group.id,
      )

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Sprint Board")

      boards_page.click_board("Sprint Board")
      board_component = PageObjects::Components::BoardsBoard.new
      board_component.open_board_menu
      board_component.click_board_settings_menu_item
      boards_page.fill_modal_board_name("Updated Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(board.reload.name).to eq("Updated Board")

      boards_page.visit_page
      expect(boards_page).to have_board_listed("Updated Board")

      boards_page.click_board("Updated Board")
      board_component = PageObjects::Components::BoardsBoard.new
      board_component.open_board_menu
      board_component.click_board_settings_menu_item
      boards_page.delete_from_board_modal
      dialog.click_yes

      expect(boards_page).to have_empty_state
      expect(Boards::Board.count).to eq(0)

      boards_page.visit_page
      boards_page.click_new_board
      boards_page.save_board_modal
      expect(boards_page.board_settings_form.field("name")).to have_errors("Required")
    end

    it "can add columns to a board" do
      boards_page.visit_page
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Workflow Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board_component = PageObjects::Components::BoardsBoard.new
      board_component.open_board_menu
      board_component.click_add_column_menu_item
      boards_page.fill_modal_column_title("To Do")
      boards_page.fill_modal_column_color("C97CF4")
      boards_page.save_column_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board_component = PageObjects::Components::BoardsBoard.new
      board_component.open_board_menu
      board_component.click_add_column_menu_item
      boards_page.fill_modal_column_title("Done")
      boards_page.save_column_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = Boards::Board.last
      expect(board.name).to eq("Workflow Board")
      expect(board.columns.order(:position).pluck(:title)).to eq(["To Do", "Done"])

      expect(boards_page).to have_column("To Do")
      expect(boards_page).to have_column("Done")
      expect(boards_page.column_by_title("To Do")).to have_color("C97CF4")
    end

    it "can delete a column with no cards without confirmation" do
      board = Fabricate(:boards_board, additional_manage_groups: [manage_group])
      column = Fabricate(:boards_column, board: board)
      boards_page.visit_page
      boards_page.click_board(board.name)
      column_component = boards_page.column_by_title(column.title)
      column_component.open_menu
      column_component.click_delete

      expect(toasts).to have_success(I18n.t("js.saved"))
    end

    it "requires confirmation when deleting a column with cards" do
      board = Fabricate(:boards_board, additional_manage_groups: [manage_group])
      column = Fabricate(:boards_column, board: board)
      Fabricate(:boards_card, board: board, column: column)
      boards_page.visit_page
      boards_page.click_board(board.name)
      column_component = boards_page.column_by_title(column.title)
      column_component.open_menu
      column_component.click_delete
      dialog.click_yes

      expect(toasts).to have_success(I18n.t("js.saved"))
    end

    it "requires entering the column name as delete confirmation when deleting a column with more than 5 cards" do
      board = Fabricate(:boards_board, additional_manage_groups: [manage_group])
      column = Fabricate(:boards_column, board: board)
      6.times { Fabricate(:boards_card, board: board, column: column) }
      boards_page.visit_page
      boards_page.click_board(board.name)
      column_component = boards_page.column_by_title(column.title)
      column_component.open_menu
      column_component.click_delete
      permanently_delete_confirm.fill_in_confirmation_phrase(column.title)
      permanently_delete_confirm.click_danger

      expect(toasts).to have_success(I18n.t("js.saved"))
    end

    it "persists board tag filter when creating a board with a tag" do
      Fabricate(:tag, name: "a11y")

      boards_page.visit_page
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Accessibility Board")
      boards_page.board_settings_form.field("constraint_type").select("tags")
      boards_page.select_modal_board_tag("a11y")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      board = Boards::Board.find_by(name: "Accessibility Board")
      expect(board).to be_present
      expect(board.tag_ids).to contain_exactly(Tag.find_by(name: "a11y").id)
    end

    describe "for an existing board" do
      let(:trust_level_4_group) { Group.find(Group::AUTO_GROUPS[:trust_level_4]) }

      fab!(:board) do
        Fabricate(
          :boards_board,
          name: "Simple Board",
          created_by: admin,
          additional_manage_groups: [manage_group],
        )
      end

      it "creates a column with a tag" do
        boards_page.visit_page
        boards_page.click_board("Simple Board")
        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_add_column_menu_item

        boards_page.fill_modal_column_title("Todo")
        boards_page.select_modal_column_tag(todo_tag.name)
        boards_page.save_column_modal

        column = board.reload.columns.find_by(title: "Todo")
        expect(column.tag_id).to eq(todo_tag.id)
      end

      it "can create a column using only the tag as the title" do
        boards_page.visit_page
        boards_page.click_board("Simple Board")
        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_add_column_menu_item
        boards_page.select_modal_column_tag(todo_tag.name)
        boards_page.save_column_modal
      end

      it "does not allow creating a column for the same tag twice" do
        boards_page.visit_page
        boards_page.click_board("Simple Board")
        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_add_column_menu_item
        boards_page.select_modal_column_tag(todo_tag.name)
        boards_page.save_column_modal

        expect(toasts).to have_success(I18n.t("js.saved"))

        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_add_column_menu_item
        boards_page.select_modal_column_tag(todo_tag.name)
        boards_page.save_column_modal
        expect(page).to have_content(
          I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: todo_tag.name),
        )
      end

      it "warns the user when they are removing Manage permissions from themselves" do
        visit board.url
        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_board_settings_menu_item
        access_control.remove_permission_row(type: "group", id: manage_group.id)
        boards_page.save_board_modal
        expect(access_control).to have_loss_warning(
          I18n.t("access_control_list.errors.Boards::Board_user_will_lose_permission"),
        )
        access_control.confirm_loss_warning
        expect(boards_page.board_settings_modal).to be_closed
        expect(page).to have_content(I18n.t("js.errors.reasons.forbidden"))
      end

      it "lets the user add a group with Manage permission from board settings on mobile",
         mobile: true do
        visit board.url
        board_component = PageObjects::Components::BoardsBoard.new
        board_component.open_board_menu
        board_component.click_board_settings_menu_item

        access_control.add_group(trust_level_4_group)
        access_control.row(type: "group", id: trust_level_4_group.id).select_permission("manage")
        boards_page.save_board_modal

        expect(toasts).to have_success(I18n.t("js.saved"))
      end
    end
  end

  context "when user is a regular user not in the manage group" do
    fab!(:read_group, :group)
    fab!(:board) do
      board = Fabricate(:boards_board, name: "Visible Board", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board
    end
    fab!(:column) { Fabricate(:boards_column, board: board) }

    before do
      read_group.add(regular_user)
      sign_in(regular_user)
    end

    it "can see the boards list but not management controls" do
      boards_page.visit_page

      expect(boards_page).to have_board_listed("Visible Board")
      expect(boards_page).to have_no_new_board_button
    end
  end

  context "when user is an admin" do
    before { sign_in(admin) }

    it "can manage boards regardless of group membership" do
      boards_page.visit_page
      expect(boards_page).to have_new_board_button
      boards_page.click_new_board
      boards_page.fill_modal_board_name("Admin Board")
      boards_page.save_board_modal

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(Boards::Board.find_by(name: "Admin Board")).to be_present
    end

    it "creates a column and a new tag when typing a non-existent tag" do
      board = Fabricate(:boards_board, name: "New Tag Board", created_by: admin)

      boards_page.visit_page
      boards_page.click_board("New Tag Board")
      board_component = PageObjects::Components::BoardsBoard.new
      board_component.open_board_menu
      board_component.click_add_column_menu_item

      boards_page.fill_modal_column_title("Backlog")
      boards_page.select_modal_column_tag("brand-new")
      boards_page.save_column_modal

      expect(toasts).to have_success(I18n.t("js.saved"))

      new_tag = Tag.find_by(name: "brand-new")
      expect(new_tag).to be_present

      column = board.reload.columns.find_by(title: "Backlog")
      expect(column.tag_id).to eq(new_tag.id)
    end
  end
end
