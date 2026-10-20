# frozen_string_literal: true

RSpec.describe "Capybara review artifacts" do
  fab!(:admin)
  fab!(:bot) { Fabricate(:user, username: "codex-bot") }
  fab!(:category)
  fab!(:board) do
    Boards::Board.create!(
      name: "Capybara",
      slug: "capybara",
      created_by_id: admin.id,
      category_ids: [category.id],
    )
  end
  fab!(:column) { board.columns.create!(title: "IN PROGRESS", position: 0) }
  fab!(:topic) { Fabricate(:topic_with_op, user: admin, category: category) }
  fab!(:card) { Fabricate(:boards_topic_card, board: board, column: column, topic: topic) }

  before do
    SiteSetting.kanban_dev_bot_enabled = true
    SiteSetting.capybara_enabled = false if SiteSetting.respond_to?(:capybara_enabled)
    SiteSetting.boards_enabled = true
    Fabricate(:access_control_list_with_users, target: board, permission: "edit", users: [bot])
    PluginStore.set(
      KanbanDevBot::STORE,
      "card-#{card.id}",
      { run_id: "artifact-run-123", status: "running", version: card.column_changed_at.iso8601(6) },
    )
    sign_in(bot)
  end

  around { |example| stub_const(KanbanDevBot, :BOARD_ID, board.id) { example.run } }

  def payload
    {
      card_id: card.id,
      run_id: "artifact-run-123",
      expected_run_id: "artifact-run-123",
      expected_version: card.reload.column_changed_at.iso8601(6),
    }
  end

  def review_file(
    path = "doc/guide.md",
    content = "# Generated guide\n\nReview these instructions."
  )
    {
      path: path,
      sha256: Digest::SHA256.hexdigest(content),
      content_base64: Base64.strict_encode64(content),
    }
  end

  describe "POST /codex-board-bot/review-artifacts" do
    it "returns persistent native upload links and reuses uploads after response loss" do
      request_payload = payload.merge(files: [review_file])
      original_extensions = SiteSetting.authorized_extensions
      post "/codex-board-bot/review-artifacts.json", params: request_payload, as: :json
      expect(response.status).to eq(200)
      first = response.parsed_body.fetch("files").first
      upload = Upload.find(first.fetch("upload_id"))
      expect(first.fetch("short_url")).to eq(upload.short_url)
      expect(first.fetch("path")).to eq("doc/guide.md")
      expect(UserUpload.exists?(user_id: bot.id, upload_id: upload.id)).to eq(true)
      expect(SiteSetting.authorized_extensions).to eq(original_extensions)

      expect do
        post "/codex-board-bot/review-artifacts.json", params: request_payload, as: :json
      end.not_to change(Upload, :count)
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("files").first).to eq(first)
    end

    it "rejects stale runs, moved cards, traversal, executable uploads, and invalid content" do
      request_payload = payload.merge(files: [review_file])
      post "/codex-board-bot/review-artifacts.json",
           params: request_payload.merge(run_id: "superseded-123"),
           as: :json
      expect(response.status).to eq(409)

      [
        review_file("../guide.md"),
        review_file(".env"),
        review_file("credentials/guide.md"),
        review_file("page.html"),
        review_file("script.js"),
        review_file("guide.md").merge(sha256: "0" * 64),
      ].each do |file|
        expect do
          post "/codex-board-bot/review-artifacts.json",
               params: request_payload.merge(files: [file]),
               as: :json
        end.not_to change(Upload, :count)
        expect(response.status).to eq(400)
      end
      column.update!(title: "DONE")
      post "/codex-board-bot/review-artifacts.json", params: request_payload, as: :json
      expect(response.status).to eq(409)
    end

    it "enforces per-file and bundle count limits before creating uploads" do
      [
        [review_file("large.md", "a" * ((2 * 1024 * 1024) + 1))],
        Array.new(25) { |index| review_file("guide#{index}.md") },
      ].each do |files|
        expect do
          post "/codex-board-bot/review-artifacts.json",
               params: payload.merge(files: files),
               as: :json
        end.not_to change(Upload, :count)
        expect(response.status).to eq(400)
      end
    end

    it "requires the bot identity and visibility of the topic" do
      sign_in(admin)
      post "/codex-board-bot/review-artifacts.json",
           params: payload.merge(files: [review_file]),
           as: :json
      expect(response.status).to eq(403)

      sign_in(bot)
      category.update!(read_restricted: true)
      category.set_permissions(staff: :full)
      category.save!
      post "/codex-board-bot/review-artifacts.json",
           params: payload.merge(files: [review_file]),
           as: :json
      expect(response.status).to eq(403)
    end
  end

  describe "POST /codex-board-bot/review-handoff" do
    it "revises the same run's handoff once and keeps Markdown, diff, and upload references" do
      column.update!(title: "REVIEW")
      PluginStore.set(
        KanbanDevBot::STORE,
        "card-#{card.id}",
        {
          run_id: "artifact-run-123",
          status: "review",
          version: card.column_changed_at.iso8601(6),
        },
      )
      original =
        PostCreator.create!(
          bot,
          topic_id: topic.id,
          raw: "Existing review summary",
          skip_validations: true,
        )
      original.custom_fields["capybara_bot_run"] = "artifact-run-123"
      original.save_custom_fields
      post "/codex-board-bot/review-artifacts.json",
           params:
             payload.merge(
               files: [review_file, review_file("review.diff", "diff --git a/file b/file\n")],
             ),
           as: :json
      expect(response.status).to eq(200)
      files = response.parsed_body.fetch("files")
      message =
        "# Generated guide\n\n[Guide](#{files[0]["short_url"]})\n\n[Full diff](#{files[1]["short_url"]})\n\nTest results\n\n116 tests passed."
      request_payload = payload.merge(message: message)
      expect do
        post "/codex-board-bot/review-handoff.json", params: request_payload, as: :json
      end.not_to change(Post, :count)
      expect(response.status).to eq(200)
      expect(original.reload.raw).to eq(message)
      expect(original.cooked).to include("<h1", "Generated guide", "Full diff", "116 tests passed")
      expect(original.uploads.pluck(:id)).to contain_exactly(
        *files.map { |file| file["upload_id"] },
      )
      expect(card.reload.column_id).to eq(column.id)
      revisions = original.revisions.count

      post "/codex-board-bot/review-handoff.json", params: request_payload, as: :json
      expect(response.status).to eq(200)
      expect(original.reload.revisions.count).to eq(revisions)
      expect(topic.posts.where(user_id: bot.id).count).to eq(1)
    end

    it "creates one supplemental handoff when a same-run post is absent" do
      column.update!(title: "REVIEW")
      PluginStore.set(
        KanbanDevBot::STORE,
        "card-#{card.id}",
        {
          run_id: "artifact-run-123",
          status: "review",
          version: card.column_changed_at.iso8601(6),
        },
      )
      request_payload = payload.merge(message: "# Current result\n\nNo tests were reported.")
      expect do
        post "/codex-board-bot/review-handoff.json", params: request_payload, as: :json
      end.to change(Post, :count).by(1)
      expect(response.status).to eq(200)
      expect do
        post "/codex-board-bot/review-handoff.json", params: request_payload, as: :json
      end.not_to change(Post, :count)
      expect(response.status).to eq(200)
    end

    it "rejects superseded and moved review cards without posting" do
      request_payload = payload.merge(message: "Stale review artifacts")
      post "/codex-board-bot/review-handoff.json", params: request_payload, as: :json
      expect(response.status).to eq(409)
      column.update!(title: "REVIEW")
      PluginStore.set(
        KanbanDevBot::STORE,
        "card-#{card.id}",
        {
          run_id: "artifact-run-123",
          status: "review",
          version: card.column_changed_at.iso8601(6),
        },
      )
      expect do
        post "/codex-board-bot/review-handoff.json",
             params: request_payload.merge(expected_run_id: "old-run-123"),
             as: :json
      end.not_to change(Post, :count)
      expect(response.status).to eq(409)
    end
  end
end
