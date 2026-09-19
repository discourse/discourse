# frozen_string_literal: true

describe "Boards Card URL" do
  fab!(:admin)
  fab!(:write_group, :group)
  fab!(:manage_group, :group)

  let(:board_viewer) { PageObjects::Pages::BoardsBoardViewer.new }

  before do
    enable_current_plugin
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    write_group.add(admin)
    manage_group.add(admin)
  end

  def create_board_with_floater
    board =
      Boards::Board.create!(name: "URL Test Board", slug: "url-test-board", created_by_id: admin.id)
    Fabricate(
      :access_control_list_with_groups,
      target: board,
      permission: "edit",
      groups: [write_group],
    )
    column = board.columns.create!(title: "To Do", position: 0)
    card =
      board.cards.create!(
        card_type: :floater,
        title: "Deep link card",
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )
    [board, column, card]
  end

  it "updates URL when clicking a floater card and restores on close" do
    board, _, card = create_board_with_floater

    sign_in(admin)
    board_viewer.visit_board(board)
    board_viewer.click_floater_card("Deep link card")

    expect(board_viewer).to have_card_detail_modal
    expect(page).to have_current_path("/boards/url-test-board/#{board.id}/cards/#{card.id}")

    board_viewer.cancel_card_detail

    expect(board_viewer).to have_no_card_detail_modal
    expect(page).to have_current_path("/boards/url-test-board/#{board.id}")
  end

  it "opens modal when visiting a card URL directly" do
    board, _, _ = create_board_with_floater

    sign_in(admin)
    board_viewer.visit_card(board, Boards::Card.last)

    expect(board_viewer).to have_board_title("URL Test Board")
    expect(board_viewer).to have_card_detail_modal
  end

  it "falls back to board URL for a non-existent card" do
    board, _, _ = create_board_with_floater

    sign_in(admin)
    page.visit "/boards/url-test-board/#{board.id}/cards/999999"

    expect(board_viewer).to have_board_title("URL Test Board")
    expect(board_viewer).to have_no_card_detail_modal
    expect(page).to have_current_path("/boards/url-test-board/#{board.id}")
  end

  it "updates URL when opening card from the actions menu" do
    board, _, card = create_board_with_floater

    sign_in(admin)
    board_viewer.visit_board(board)
    board_viewer.open_card_actions("Deep link card")
    board_viewer.click_edit_card

    expect(board_viewer).to have_card_detail_modal
    expect(page).to have_current_path("/boards/url-test-board/#{board.id}/cards/#{card.id}")
  end
end
