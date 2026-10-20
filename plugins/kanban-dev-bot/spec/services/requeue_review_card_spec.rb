# frozen_string_literal: true

RSpec.describe KanbanDevBot::RequeueReviewCard do
  fab!(:admin)
  fab!(:user)
  fab!(:bot) { Fabricate(:user, username: "codex-bot") }
  fab!(:topic) { Fabricate(:topic_with_op, user: admin) }
  fab!(:board) { Fabricate(:boards_board, created_by: admin) }
  fab!(:review) { Fabricate(:boards_column, board: board, title: "REVIEW") }
  fab!(:todo) { Fabricate(:boards_column, board: board, title: "TODO") }
  fab!(:card) { Fabricate(:boards_topic_card, board: board, column: review, topic: topic) }

  before do
    SiteSetting.kanban_dev_bot_enabled = true
    SiteSetting.capybara_enabled = false if SiteSetting.respond_to?(:capybara_enabled)
    SiteSetting.boards_enabled = true
    Fabricate(:access_control_list_with_users, target: board, permission: "edit", users: [bot])
  end

  around { |example| stub_const(KanbanDevBot, :BOARD_ID, board.id) { example.run } }

  describe ".call" do
    it "queues a human reply through the post-created hook even without board editing access" do
      version = card.column_changed_at
      run = {
        "run_id" => "previous-review-run",
        "status" => "review",
        "version" => version.iso8601(6),
      }
      PluginStore.set(KanbanDevBot::STORE, "card-#{card.id}", run)
      expect(user.guardian.can_write_board?(board)).to eq(false)
      messages =
        MessageBus.track_publish do
          PostCreator.create!(
            user,
            topic_id: topic.id,
            raw: "Please adjust the design",
            skip_validations: true,
          )
        end

      expect(card.reload.column_id).to eq(todo.id)
      expect(card.column_changed_at).to be > version
      expect(card.updated_by_id).to eq(bot.id)
      expect(PluginStore.get(KanbanDevBot::STORE, "card-#{card.id}")).to eq(run)
      history =
        Boards::CardHistory.where(card: card, action: Boards::CardHistory.actions[:card_moved]).sole
      expect(history.acting_user_id).to eq(bot.id)
      expect(history.details).to eq("from" => "REVIEW", "to" => "TODO")
      board_messages = messages.select { |message| message.channel == "/boards/#{board.id}" }
      expect(board_messages.map { |message| message.data[:type] }).to contain_exactly(
        "board_updated",
      )
      topic_messages = messages.select { |message| message.channel == "/topic/#{topic.id}" }
      expect(topic_messages.any? { |message| message.data[:reload_topic] }).to eq(true)
    end

    it "leaves an untagged bot reply in REVIEW" do
      PostCreator.create!(
        bot,
        topic_id: topic.id,
        raw: "Here is your preview",
        skip_validations: true,
      )
      expect(card.reload.column_id).to eq(review.id)
    end

    it "handles a repeated post-created delivery without another move" do
      reply =
        PostCreator.create!(
          user,
          topic_id: topic.id,
          raw: "Another change please",
          skip_validations: true,
        )
      version = card.reload.column_changed_at
      expect { DiscourseEvent.trigger(:post_created, reply, {}) }.not_to change {
        Boards::CardHistory.where(card: card).count
      }
      expect(card.reload.column_changed_at).to eq_time(version)
    end

    it "leaves every other column unchanged" do
      ["BACKLOG", "TODO", "IN PROGRESS", "DONE", "ARCHIVED"].each do |title|
        column =
          board.columns.find_by(title: title) ||
            Fabricate(:boards_column, board: board, title: title)
        card.update!(column: column)
        PostCreator.create!(
          user,
          topic_id: topic.id,
          raw: "Feedback in #{title}",
          skip_validations: true,
        )
        expect(card.reload.column_id).to eq(column.id)
      end
    end

    it "ignores original posts, system posts, whispers, deleted posts, and imports" do
      reply = Fabricate(:post, topic: topic, user: user, post_number: 2)
      [
        { post_number: 1 },
        { user_id: Discourse.system_user.id },
        { post_type: Post.types[:small_action] },
        { post_type: Post.types[:whisper] },
        { deleted_at: Time.zone.now },
      ].each do |attributes|
        described_class.call(Post.find(reply.id).tap { |post| post.assign_attributes(attributes) })
        expect(card.reload.column_id).to eq(review.id)
      end
      described_class.call(reply, import_mode: true)
      expect(card.reload.column_id).to eq(review.id)
    end

    it "ignores replies when disabled or in production" do
      reply = Fabricate(:post, topic: topic, user: user)
      SiteSetting.kanban_dev_bot_enabled = false
      SiteSetting.capybara_enabled = true if SiteSetting.respond_to?(:capybara_enabled)
      described_class.call(reply)
      expect(card.reload.column_id).to eq(review.id)
      SiteSetting.kanban_dev_bot_enabled = true
      Rails.env.stubs(:production?).returns(true)
      described_class.call(reply)
      expect(card.reload.column_id).to eq(review.id)
    end

    it "ignores other boards, archived boards, and deleted topics" do
      reply = Fabricate(:post, topic: topic, user: user)
      stub_const(KanbanDevBot, :BOARD_ID, board.id + 1) { described_class.call(reply) }
      expect(card.reload.column_id).to eq(review.id)
      board.update!(archived: true)
      described_class.call(reply)
      expect(card.reload.column_id).to eq(review.id)
      board.update!(archived: false)
      topic.update_columns(deleted_at: Time.zone.now)
      described_class.call(reply.reload)
      expect(card.reload.column_id).to eq(review.id)
    end

    it "leaves a floater card unchanged" do
      card.update!(topic: nil, card_type: :floater, title: "A loose card")
      PostCreator.create!(
        user,
        topic_id: topic.id,
        raw: "Feedback without a topic card",
        skip_validations: true,
      )
      expect(card.reload.column_id).to eq(review.id)
    end
  end
end
