# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CardMoved::V2 do
  fab!(:manager, :user)
  fab!(:board, :boards_board)
  fab!(:old_column) { Fabricate(:boards_column, board:) }
  fab!(:new_column) { Fabricate(:boards_column, board:) }
  fab!(:card) { Fabricate(:boards_card, board:, column: new_column) }

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.boards_enabled = true
  end

  it "returns the user who moved the card as actor", :aggregate_failures do
    trigger =
      described_class.new(
        board,
        { id: card.id, old_column_id: old_column.id, column_id: new_column.id },
        manager,
      )

    expect(trigger.output[:actor]).to include(id: manager.id, username: manager.username)
    expect(trigger.output).not_to have_key(:acting_user)
    expect(trigger.output).to match_node_output_schema(described_class)
  end
end
