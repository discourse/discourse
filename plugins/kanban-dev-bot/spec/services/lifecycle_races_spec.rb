# frozen_string_literal: true

require "timeout"

RSpec.describe KanbanDevBot::Lifecycle, ".lock" do
  self.use_transactional_tests = false

  before do
    @database_config = ActiveRecord::Base.connection_db_config.configuration_hash
    ActiveRecord::Base.establish_connection(@database_config.merge(pool: 5))
    SiteSetting.boards_enabled = true
    SiteSetting.kanban_dev_bot_enabled = true
    @admin =
      Fabricate(
        :admin,
        username: "race_#{SecureRandom.hex(6)}",
        email: "#{SecureRandom.hex(12)}@example.com",
      )
    @board = Fabricate(:boards_board, created_by: @admin)
    @review = Fabricate(:boards_column, board: @board, title: "REVIEW")
    @done = Fabricate(:boards_column, board: @board, title: "DONE")
    @topic = Fabricate(:topic, user: @admin)
    Fabricate(:post, topic: @topic, user: @admin)
    @card = Fabricate(:boards_topic_card, board: @board, column: @review, topic: @topic)
    KanbanDevBot::Lifecycle.save(
      @card,
      {
        "run_id" => "race-run-123",
        "status" => "review",
        "version" => @card.column_changed_at.iso8601(6),
        "commit" => "a" * 40,
        "base_commit" => "b" * 40,
      },
    )
  end

  after do
    SiteSetting.kanban_dev_bot_enabled = false
    PluginStore.remove(KanbanDevBot::STORE, "card-#{@card.id}") if @card
    @board&.destroy!
    @topic&.destroy!
    @admin&.destroy!
    ActiveRecord::Base.establish_connection(@database_config)
  end

  def accept
    Boards::UpdateCard.call!(
      guardian: @admin.guardian,
      params: {
        board_id: @board.id,
        id: @card.id,
        column_id: @done.id,
      },
      options: {
        raw_card_params: {
          "column_id" => @done.id,
        },
      },
    )
  end

  def delete
    Boards::DestroyCard.call!(
      guardian: @admin.guardian,
      params: {
        board_id: @board.id,
        id: @card.id,
      },
    )
  end

  def race(first, second)
    locked = Queue.new
    release = Queue.new
    pid = Queue.new
    results = Queue.new
    holder =
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          KanbanDevBot::Lifecycle.lock do
            first.call
            locked << true
            release.pop
          end
        end
      rescue => error
        locked << error
      end
    holder_state = Timeout.timeout(10) { locked.pop }
    raise holder_state if holder_state.is_a?(Exception)
    contender =
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          pid << connection.select_value("SELECT pg_backend_pid()")
          begin
            second.call
            results << :success
          rescue => error
            results << error
          end
        end
      end
    backend_pid = Timeout.timeout(10) { pid.pop }
    Timeout.timeout(10) do
      loop do
        waiting =
          ActiveRecord::Base.connection.select_value(
            "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{backend_pid.to_i}",
          )
        break if waiting == "Lock"
        Thread.pass
      end
    end
    release << true
    Timeout.timeout(10) do
      holder.join
      contender.join
    end
    results.pop
  ensure
    release << true if release
    [holder, contender].compact.each { |thread| thread.kill if thread.alive? }
  end

  it "rejects deletion that races with acceptance committed first" do
    stub_const(KanbanDevBot, :BOARD_ID, @board.id) do
      result = race(-> { accept }, -> { delete })
      expect(result).to be_a(Discourse::InvalidParameters)
      expect(@card.reload.column_id).to eq(@done.id)
      expect(KanbanDevBot::Lifecycle.run(@card)["accepted_commit"]).to eq("a" * 40)
    end
  end

  it "does not accept a card deleted by the transaction that won" do
    stub_const(KanbanDevBot, :BOARD_ID, @board.id) do
      result = race(-> { delete }, -> { accept })
      expect(result).to be_a(Service::Base::Failure)
      expect(Boards::Card.exists?(@card.id)).to eq(false)
      expect(KanbanDevBot::Lifecycle.run(@card)).to include("deleted" => true)
      expect(KanbanDevBot::Lifecycle.run(@card)["accepted_at"]).to be_nil
    end
  end

  it "rejects a bulk clear waiting behind acceptance without removing sibling cards" do
    other = Fabricate(:boards_card, board: @board, column: @done)
    stub_const(KanbanDevBot, :BOARD_ID, @board.id) do
      result =
        race(
          -> { accept },
          -> do
            Boards::ClearColumn.call!(
              guardian: @admin.guardian,
              params: {
                board_id: @board.id,
                column_id: @done.id,
              },
            )
          end,
        )
      expect(result).to be_a(Discourse::InvalidParameters)
      expect(Boards::Card.where(id: [@card.id, other.id]).count).to eq(2)
    end
  end

  it "does not requeue a reply after acceptance wins the lock" do
    bot = Fabricate(:user, username: "codex-bot", email: "#{SecureRandom.hex(12)}@example.com")
    Fabricate(:access_control_list_with_users, target: @board, permission: "edit", users: [bot])
    Fabricate(:boards_column, board: @board, title: "TODO")
    reply = Fabricate(:post, topic: @topic, user: @admin)
    stub_const(KanbanDevBot, :BOARD_ID, @board.id) do
      result = race(-> { accept }, -> { KanbanDevBot::RequeueReviewCard.call(reply) })
      expect(result).to eq(:success)
      expect(@card.reload.column_id).to eq(@done.id)
    end
  ensure
    bot&.destroy!
  end

  it "serializes conflicting restart and cancel requests" do
    stub_const(KanbanDevBot, :BOARD_ID, @board.id) do
      result =
        race(
          -> { KanbanDevBot::Lifecycle.request!(@card, "restart", "race-run-123") },
          -> do
            KanbanDevBot::Lifecycle.lock do
              KanbanDevBot::Lifecycle.request!(@card, "cancel", "race-run-123")
            end
          end,
        )
      expect(result).to be_a(Discourse::InvalidParameters)
      expect(KanbanDevBot::Lifecycle.run(@card)["requested_action"]).to eq("restart")
    end
  end
end
