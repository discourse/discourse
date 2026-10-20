# frozen_string_literal: true

RSpec.describe "Kanban development bot" do
  fab!(:admin)
  fab!(:category)
  fab!(:board) do
    Boards::Board.create!(
      name: "Capybara",
      slug: "capybara",
      created_by_id: admin.id,
      category_ids: [category.id],
    )
  end
  fab!(:column) { board.columns.create!(title: "BACKLOG", position: 0) }

  before do
    SiteSetting.kanban_dev_bot_enabled = true
    SiteSetting.capybara_enabled = false if SiteSetting.respond_to?(:capybara_enabled)
    SiteSetting.boards_enabled = true
    Fabricate(:access_control_list_with_users, target: board, permission: "edit", users: [admin])
    sign_in(admin)
  end

  around { |example| stub_const(KanbanDevBot, :BOARD_ID, board.id) { example.run } }

  describe "GET /codex-board-bot/snapshot" do
    it "rejects bot requests when disabled even when Capybara is enabled" do
      SiteSetting.kanban_dev_bot_enabled = false
      SiteSetting.capybara_enabled = true if SiteSetting.respond_to?(:capybara_enabled)

      get "/codex-board-bot/snapshot.json"

      expect(response.status).to eq(404)
    end

    it "includes the latest human replies and their attached images" do
      result =
        Boards::CreateCard.call(
          guardian: admin.guardian,
          params: {
            board_id: board.id,
            column_id: column.id,
            title: "Screenshot task",
            notes: "Implement this design",
          },
        )
      card = result[:card]
      reply =
        PostCreator.create!(
          admin,
          topic_id: card.topic_id,
          raw: "Here is the revised screenshot",
          skip_validations: true,
        )
      image =
        Fabricate(
          :upload,
          extension: "png",
          original_filename: "design.png",
          width: 100,
          height: 80,
        )
      UploadReference.ensure_exist!(upload_ids: [image.id], target: reply)
      bot_post =
        PostCreator.create!(
          admin,
          topic_id: card.topic_id,
          raw: "Generated status report",
          skip_validations: true,
        )
      bot_post.custom_fields["capybara_bot_run"] = "test-run-123"
      bot_post.save_custom_fields

      get "/codex-board-bot/snapshot.json"

      expect(response.status).to eq(200)
      snapshot = response.parsed_body.fetch("cards").find { |candidate| candidate["id"] == card.id }
      expect(snapshot.fetch("discussion").map { |post| post["raw"] }).to eq(
        ["Implement this design", reply.raw],
      )
      expect(snapshot.fetch("attachments")).to contain_exactly(
        "id" => image.id,
        "url" => "/codex-board-bot/uploads/#{image.id}",
        "original_filename" => "design.png",
        "width" => 100,
        "height" => 80,
      )
    end

    it "rejects normal board viewers from the bot API" do
      sign_in(Fabricate(:user))
      get "/codex-board-bot/snapshot.json"
      expect(response.status).to eq(403)
    end
  end

  describe "POST /codex-board-bot/transition" do
    it "reports integration progress and failures once without treating them as completion" do
      result =
        Boards::CreateCard.call(
          guardian: admin.guardian,
          params: {
            board_id: board.id,
            column_id: column.id,
            title: "Merge this topic task",
            notes: "Keep this requirement",
          },
        )
      card = result[:card]
      column.update!(title: "DONE")
      PluginStore.set(
        KanbanDevBot::STORE,
        "card-#{card.id}",
        { run_id: "test-run-123", status: "review", version: card.column_changed_at.iso8601(6) },
      )

      %w[integrating integration_failed done].each do |command|
        payload = {
          command: command,
          card_id: card.id,
          run_id: "test-run-123",
          expected_run_id: "test-run-123",
          expected_version: card.reload.column_changed_at.iso8601(6),
          message: "Status #{command}",
        }
        expect do post "/codex-board-bot/transition.json", params: payload end.to change {
          card.topic.posts.count
        }.by(1)
        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("run", "status")).to eq(command)
        expect do post "/codex-board-bot/transition.json", params: payload end.not_to change {
          card.topic.posts.count
        }
      end
      expect(card.topic.first_post.raw).to eq("Keep this requirement")
    end
  end

  describe "POST /codex-board-bot/setup" do
    before do
      Fabricate(
        :access_control_list_with_users,
        target: board,
        permission: "manage",
        users: [admin],
      )
    end

    it "creates ARCHIVED after DONE and preserves its identity on repeated setup" do
      done = board.columns.create!(title: "DONE", position: 1)
      post "/codex-board-bot/setup.json"
      expect(response.status).to eq(200)
      archived = board.columns.find_by!(title: "ARCHIVED")
      ids = board.columns.order(:position, :id).pluck(:id)
      expect(ids).to eq([column.id, done.id, archived.id])
      post "/codex-board-bot/setup.json"
      expect(response.status).to eq(200)
      expect(board.columns.where(title: "ARCHIVED").count).to eq(1)
      expect(board.columns.order(:position, :id).pluck(:id)).to eq(ids)
    end

    it "moves an existing ARCHIVED column directly after DONE while preserving other columns" do
      done = board.columns.create!(title: "DONE", position: 1)
      extra = board.columns.create!(title: "Reference", position: 2)
      archived = board.columns.create!(title: "ARCHIVED", position: 3)
      post "/codex-board-bot/setup.json"
      expect(response.status).to eq(200)
      expect(board.columns.order(:position, :id).pluck(:id)).to eq(
        [column.id, done.id, archived.id, extra.id],
      )
    end

    it "repairs an existing ARCHIVED column before DONE without replacing columns" do
      archived = board.columns.create!(title: "ARCHIVED", position: 1)
      done = board.columns.create!(title: "DONE", position: 2)
      extra = board.columns.create!(title: "Reference", position: 3)
      post "/codex-board-bot/setup.json"
      expect(response.status).to eq(200)
      expect(board.columns.order(:position, :id).pluck(:id)).to eq(
        [column.id, done.id, archived.id, extra.id],
      )
    end
  end

  describe "POST /codex-board-bot/transition archive" do
    fab!(:archived_column) { board.columns.create!(title: "ARCHIVED", position: 1) }
    fab!(:topic) { Fabricate(:topic_with_op, user: admin, category: category) }
    fab!(:card) { Fabricate(:boards_topic_card, board: board, column: column, topic: topic) }

    before do
      column.update!(title: "DONE")
      PluginStore.set(
        KanbanDevBot::STORE,
        "card-#{card.id}",
        { run_id: "archive-run-123", status: "review", version: card.column_changed_at.iso8601(6) },
      )
    end

    let(:payload) do
      {
        command: "archive",
        card_id: card.id,
        run_id: "archive-run-123",
        expected_run_id: "archive-run-123",
        expected_version: card.column_changed_at.iso8601(6),
        message: "Merged and confirmed pushed",
      }
    end

    it "moves the matching completed run once and publishes board and topic updates" do
      original = payload
      messages =
        MessageBus.track_publish { post "/codex-board-bot/transition.json", params: original }
      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(archived_column.id)
      expect(response.parsed_body.dig("run", "status")).to eq("done")
      expect(topic.reload).not_to be_closed
      expect(messages.any? { |message| message.channel == "/boards/#{board.id}" }).to eq(true)
      expect(messages.any? { |message| message.channel == "/topic/#{topic.id}" }).to eq(true)
      expect(Boards::CardHistory.where(card: card, action: :card_moved).count).to eq(1)
      expect { post "/codex-board-bot/transition.json", params: original }.not_to change {
        topic.posts.count
      }
      expect(response.status).to eq(200)
      expect(Boards::CardHistory.where(card: card, action: :card_moved).count).to eq(1)
    end

    it "rejects a superseded run without moving the card" do
      post "/codex-board-bot/transition.json",
           params: payload.merge(run_id: "superseded-123", expected_run_id: "superseded-123")
      expect(response.status).to eq(409)
      expect(card.reload.column_id).to eq(column.id)
    end

    it "rejects a stale version without moving the card" do
      post "/codex-board-bot/transition.json",
           params: payload.merge(expected_version: 1.day.ago.iso8601(6))
      expect(response.status).to eq(409)
      expect(card.reload.column_id).to eq(column.id)
    end

    it "keeps the legacy done acknowledgment in DONE" do
      post "/codex-board-bot/transition.json", params: payload.merge(command: "done")
      expect(response.status).to eq(200)
      expect(card.reload.column_id).to eq(column.id)
    end
  end

  describe "GET /codex-board-bot/uploads/:id" do
    it "serves only images referenced by a visible card topic" do
      result =
        Boards::CreateCard.call(
          guardian: admin.guardian,
          params: {
            board_id: board.id,
            column_id: column.id,
            title: "View this screenshot",
            notes: "Image requirements",
          },
        )
      card = result[:card]
      image = UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(admin.id)
      UploadReference.ensure_exist!(upload_ids: [image.id], target: card.topic.first_post)

      get "/codex-board-bot/uploads/#{image.id}"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("image/png")

      UploadReference.where(upload_id: image.id).delete_all
      get "/codex-board-bot/uploads/#{image.id}"
      expect(response.status).to eq(404)
    end
  end
end
