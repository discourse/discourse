# frozen_string_literal: true

RSpec.describe KanbanDevBot::Lifecycle do
  fab!(:admin)
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:backlog) { Fabricate(:boards_column, board: board, title: "BACKLOG") }
  fab!(:todo) { Fabricate(:boards_column, board: board, title: "TODO") }
  fab!(:running) { Fabricate(:boards_column, board: board, title: "IN PROGRESS") }
  fab!(:review) { Fabricate(:boards_column, board: board, title: "REVIEW") }
  fab!(:done) { Fabricate(:boards_column, board: board, title: "DONE") }
  fab!(:archived) { Fabricate(:boards_column, board: board, title: "ARCHIVED") }
  fab!(:topic) { Fabricate(:topic_with_op, user: admin) }
  fab!(:card) { Fabricate(:boards_topic_card, board: board, column: review, topic: topic) }

  before do
    SiteSetting.boards_enabled = true
    SiteSetting.kanban_dev_bot_enabled = true
    described_class.save(
      card,
      {
        "run_id" => "lifecycle-run-123",
        "status" => "review",
        "version" => card.column_changed_at.iso8601(6),
        "commit" => "a" * 40,
        "base_commit" => "b" * 40,
      },
    )
  end

  around { |example| stub_const(KanbanDevBot, :BOARD_ID, board.id) { example.run } }

  def move(column, bang: false)
    Boards::UpdateCard.public_send(
      bang ? :call! : :call,
      guardian: admin.guardian,
      params: {
        board_id: board.id,
        id: card.id,
        column_id: column.id,
      },
      options: {
        raw_card_params: {
          "column_id" => column.id,
        },
      },
    )
  end

  it "atomically accepts the reviewed commit and locks moves and deletion" do
    expect(move(done)).to be_success
    state = described_class.run(card)
    expect(state).to include("accepted_commit" => "a" * 40, "status" => "integrating")
    expect(state["accepted_at"]).to be_present
    expect { move(todo, bang: true) }.to raise_error(Discourse::InvalidParameters)
    expect {
      Boards::DestroyCard.call(
        guardian: admin.guardian,
        params: {
          board_id: board.id,
          id: card.id,
        },
      )
    }.to raise_error(Discourse::InvalidParameters)
    expect { topic.trash!(admin) }.to raise_error(Discourse::InvalidParameters)
    expect(card.reload.column).to eq(done)
    expect(topic.reload).not_to be_closed
  end

  it "does not renew acceptance on same-column updates" do
    move(done)
    state = described_class.run(card)
    move(done)
    expect(described_class.run(card)).to eq(state)
  end

  it "rejects human moves to every bot-owned column through call and call!" do
    [running, archived].each do |column|
      [false, true].each do |bang|
        expect { move(column, bang: bang) }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end

  it "requires synchronized review metadata" do
    described_class.save(card, described_class.run(card).except("commit"))
    expect { move(done) }.to raise_error(Discourse::InvalidParameters)
    expect(card.reload.column).to eq(review)
  end

  it "fences cancellation and rejects conflicting actions" do
    first = described_class.request!(card, "restart", "lifecycle-run-123")
    expect(first).to include("status" => "stopping", "phase" => "stopping")
    expect(described_class.request!(card, "restart", "lifecycle-run-123")).to eq(first)
    expect { described_class.request!(card, "cancel", "lifecycle-run-123") }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect { move(todo) }.to raise_error(Discourse::InvalidParameters)
  end

  it "preflights bulk clear without deleting any card or closing any topic" do
    other = Fabricate(:boards_topic_card, board: board, column: done)
    move(done)
    expect {
      Boards::ClearColumn.call!(
        guardian: admin.guardian,
        params: {
          board_id: board.id,
          column_id: done.id,
        },
      )
    }.to raise_error(Discourse::InvalidParameters)
    expect(Boards::Card.where(id: [card.id, other.id]).count).to eq(2)
    expect(topic.reload).not_to be_closed
  end

  it "closes topics and persists cleanup tombstones when clearing active cards" do
    Boards::ClearColumn.call!(
      guardian: admin.guardian,
      params: {
        board_id: board.id,
        column_id: review.id,
      },
    )
    expect(Boards::Card.exists?(card.id)).to eq(false)
    expect(topic.reload).to be_closed
    expect(described_class.operations).to include(
      include(card_id: card.id, run: include("deleted" => true, "requested_action" => "cancel")),
    )
  end

  it "blocks structural changes and board deletion once a card is accepted" do
    move(done)
    expect {
      Boards::DestroyBoard.call!(guardian: admin.guardian, params: { id: board.id })
    }.to raise_error(Discourse::InvalidParameters)
    expect {
      Boards::DestroyColumn.call!(
        guardian: admin.guardian,
        params: {
          board_id: board.id,
          id: done.id,
        },
      )
    }.to raise_error(Discourse::InvalidParameters)
    expect {
      Boards::Archive.call!(guardian: admin.guardian, params: { board_id: board.id })
    }.to raise_error(Discourse::InvalidParameters)
    expect {
      Boards::ColumnsReplacer.replace!(board: board, columns_payload: [], user: admin)
    }.to raise_error(Discourse::InvalidParameters)
  end

  it "preserves replies when permanent first-post deletion is rejected" do
    reply = Fabricate(:post, topic: topic, user: admin)
    move(done)
    expect { PostDestroyer.new(admin, topic.first_post, permanent: true).destroy }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect(Post.exists?(reply.id)).to eq(true)
    expect(Post.exists?(topic.first_post.id)).to eq(true)
  end

  it "does not let topic synchronization remove a managed card" do
    board.update!(category_ids: [Fabricate(:category).id])
    Boards::TopicSync.sync_topic(topic)
    Boards::TopicSync.backfill_board(board)
    expect(Boards::Card.exists?(card.id)).to eq(true)
  end

  it "rejects legacy floater promotion into an accepted topic card" do
    move(done)
    floater = Fabricate(:boards_card, board: board, column: backlog)
    expect do
      Boards::UpdateCard.call!(
        guardian: admin.guardian,
        params: {
          board_id: board.id,
          id: floater.id,
          topic_id: topic.id,
          column_id: done.id,
        },
      )
    end.to raise_error(Discourse::InvalidParameters)
    expect(Boards::Card.exists?(floater.id)).to eq(true)
    expect(card.reload.column_id).to eq(done.id)
  end

  it "keeps out-of-constraint accepted cards during an otherwise harmless board rename" do
    move(done)
    board.update!(category_ids: [Fabricate(:category).id])
    Boards::UpdateBoard.call!(
      guardian: admin.guardian,
      params: {
        id: board.id,
      },
      raw_board_params: {
        "name" => "Renamed",
      },
    )
    expect(Boards::Card.exists?(card.id)).to eq(true)
  end

  it "exposes separate creation and drop capabilities" do
    data = Boards::ColumnSerializer.new(done, root: false, scope: admin.guardian).as_json
    expect(data[:can_add_cards]).to eq(false)
    expect(data[:can_receive_cards]).to eq(true)
    basic =
      Boards::BasicColumnSerializer.new(
        running,
        root: false,
        scope: admin.guardian,
        board_memberships: [],
      ).as_json
    expect(basic[:can_add_cards]).to eq(false)
  end
end
