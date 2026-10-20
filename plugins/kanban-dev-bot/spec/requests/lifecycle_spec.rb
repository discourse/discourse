# frozen_string_literal: true

RSpec.describe "Kanban lifecycle actions" do
  fab!(:admin)
  fab!(:bot) { Fabricate(:user, username: "codex-bot") }
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:backlog) { Fabricate(:boards_column, board: board, title: "BACKLOG") }
  fab!(:todo) { Fabricate(:boards_column, board: board, title: "TODO") }
  fab!(:running) { Fabricate(:boards_column, board: board, title: "IN PROGRESS") }
  fab!(:review) { Fabricate(:boards_column, board: board, title: "REVIEW") }
  fab!(:done) { Fabricate(:boards_column, board: board, title: "DONE") }
  fab!(:card) { Fabricate(:boards_topic_card, board: board, column: running) }

  before do
    SiteSetting.boards_enabled = true
    SiteSetting.kanban_dev_bot_enabled = true
    Fabricate(
      :access_control_list_with_users,
      target: board,
      permission: "edit",
      users: [admin, bot],
    )
    KanbanDevBot::Lifecycle.save(
      card,
      {
        "run_id" => "actions-run-123",
        "status" => "running",
        "version" => card.column_changed_at.iso8601(6),
      },
    )
    sign_in(admin)
  end

  around { |example| stub_const(KanbanDevBot, :BOARD_ID, board.id) { example.run } }

  def transition(command, **extra)
    post "/codex-board-bot/transition.json",
         params: {
           card_id: card.id,
           command: command,
           run_id: "actions-run-123",
           expected_run_id: "actions-run-123",
           expected_version: card.column_changed_at.iso8601(6),
           **extra,
         },
         as: :json
  end

  def request_action(action)
    post "/codex-board-bot/action.json",
         params: {
           card_id: card.id,
           action: action,
           expected_run_id: "actions-run-123",
         },
         as: :json
  end

  it "restricts machine transitions to the bot even for administrators" do
    transition("review", commit: "a" * 40, base_commit: "b" * 40)
    expect(response.status).to eq(403)
    expect(card.reload.column_id).to eq(running.id)
  end

  it "rejects late review after restart and acknowledges stopping idempotently" do
    request_action("restart")
    expect(response.status).to eq(200)
    action_id = response.parsed_body.dig("run", "action_id")
    expect(card.reload.column_id).to eq(running.id)
    sign_in(bot)
    transition("review", commit: "a" * 40, base_commit: "b" * 40)
    expect(response.status).to eq(409)
    transition("stopped", expected_action_id: action_id)
    expect(response.status).to eq(200)
    expect(card.reload.column_id).to eq(todo.id)
    transition("stopped", expected_action_id: action_id)
    expect(response.status).to eq(200)
    transition("stopped", expected_action_id: "stale-action")
    expect(response.status).to eq(409)
  end

  it "creates a new cleanup identity if a previously cancelled card is deleted" do
    request_action("cancel")
    old_action = response.parsed_body.dig("run", "action_id")
    sign_in(bot)
    transition("stopped", expected_action_id: old_action)
    expect(response.status).to eq(200)
    Boards::DestroyCard.call!(guardian: admin.guardian, params: { board_id: board.id, id: card.id })
    state = KanbanDevBot::Lifecycle.run(card)
    expect(state["action_id"]).not_to eq(old_action)
    transition("stopped", expected_action_id: old_action)
    expect(response.status).to eq(409)
    transition("stopped", expected_action_id: state["action_id"])
    expect(response.status).to eq(200)
    expect(KanbanDevBot::Lifecycle.run(card)["cleanup_complete"]).to eq(true)
  end

  it "keeps deleted archived cards terminal and out of recovery snapshots" do
    archived = Fabricate(:boards_column, board: board, title: "ARCHIVED")
    card.update!(column: archived)
    accepted_at = Time.now.utc.iso8601(6)
    KanbanDevBot::Lifecycle.save(
      card,
      KanbanDevBot::Lifecycle.run(card).merge(
        "status" => "archived",
        "phase" => "archived",
        "accepted_at" => accepted_at,
        "accepted_commit" => "a" * 40,
      ),
    )

    Boards::DestroyCard.call!(guardian: admin.guardian, params: { board_id: board.id, id: card.id })

    expect(Boards::Card.exists?(card.id)).to eq(false)
    state = KanbanDevBot::Lifecycle.run(card)
    expect(state).to include(
      "status" => "archived",
      "phase" => "archived",
      "accepted_at" => accepted_at,
      "accepted_commit" => "a" * 40,
      "deleted" => true,
      "cleanup_complete" => true,
    )
    expect(state["requested_action"]).to be_nil
    expect(KanbanDevBot::Lifecycle.accepted?(state)).to eq(false)
    sign_in(bot)
    get "/codex-board-bot/snapshot.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["operations"]).not_to include(include("card_id" => card.id))
  end

  it "retains accepted identity across retried phase reports" do
    card.update!(column: done)
    state =
      KanbanDevBot::Lifecycle.run(card).merge(
        "status" => "integration_failed",
        "accepted_at" => Time.now.utc.iso8601(6),
        "accepted_commit" => "a" * 40,
      )
    KanbanDevBot::Lifecycle.save(card, state)
    request_action("retry")
    expect(response.status).to eq(200)
    action_id = response.parsed_body.dig("run", "action_id")
    sign_in(bot)
    %w[integrating deploying publishing confirming].each do |phase|
      transition("phase", phase: phase, expected_action_id: action_id)
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("run", "accepted_commit")).to eq("a" * 40)
    end
  end
end
