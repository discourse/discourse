# frozen_string_literal: true

RSpec.describe Boards::Api::ColumnsController do
  fab!(:admin)
  fab!(:manager, :user)
  fab!(:outsider, :user)
  fab!(:manage_group, :group)
  fab!(:board) do
    Fabricate(:boards_board, created_by: admin, additional_manage_groups: [manage_group])
  end
  fab!(:column) { board.columns.create!(title: "Old", position: 0) }

  before do
    enable_current_plugin
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    manage_group.add(manager)
  end

  describe "POST /boards/api/boards/:board_id/columns" do
    it "creates a column for board managers" do
      sign_in(manager)

      post "/boards/api/boards/#{board.id}/columns.json", params: { column: { title: "Backlog" } }

      expect(response.status).to eq(201)
      expect(response.parsed_body["column"]["title"]).to eq("Backlog")
      expect(board.columns.order(:position).last.title).to eq("Backlog")
    end

    it "rejects users who cannot manage the board" do
      sign_in(outsider)

      post "/boards/api/boards/#{board.id}/columns.json", params: { column: { title: "Backlog" } }

      expect(response.status).to eq(403)
    end

    it "returns not found when the board does not exist" do
      sign_in(manager)

      post "/boards/api/boards/0/columns.json", params: { column: { title: "Backlog" } }

      expect(response.status).to eq(404)
    end

    it "returns bad request for invalid payloads" do
      sign_in(manager)

      post "/boards/api/boards/#{board.id}/columns.json", params: { column: { title: nil } }

      expect(response.status).to eq(400)
    end

    it "returns service errors for invalid column settings" do
      tag = Fabricate(:tag, name: "todo")
      board.columns.create!(title: "Todo", position: 1, tag_id: tag.id)
      sign_in(manager)

      post "/boards/api/boards/#{board.id}/columns.json",
           params: {
             column: {
               title: "Duplicate",
               tag_name: tag.name,
             },
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag.name),
      )
    end
  end

  describe "PUT /boards/api/boards/:board_id/columns/:id" do
    it "updates a column for board managers" do
      sign_in(manager)

      put "/boards/api/boards/#{board.id}/columns/#{column.id}.json",
          params: {
            column: {
              title: "Renamed",
              default_sort: "recency",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["column"]["title"]).to eq("Renamed")
      expect(column.reload).to have_attributes(title: "Renamed", default_sort: "recency")
    end

    it "rejects users who cannot manage the board" do
      sign_in(outsider)

      put "/boards/api/boards/#{board.id}/columns/#{column.id}.json",
          params: {
            column: {
              title: "Renamed",
            },
          }

      expect(response.status).to eq(403)
    end

    it "returns not found when the column does not exist" do
      sign_in(manager)

      put "/boards/api/boards/#{board.id}/columns/0.json", params: { column: { title: "Renamed" } }

      expect(response.status).to eq(404)
    end

    it "returns bad request for invalid payloads" do
      sign_in(manager)

      put "/boards/api/boards/#{board.id}/columns/#{column.id}.json",
          params: {
            column: {
              title: nil,
            },
          }

      expect(response.status).to eq(400)
    end
  end

  describe "DELETE /boards/api/boards/:board_id/columns/:id" do
    it "deletes a column for board managers" do
      sign_in(manager)

      delete "/boards/api/boards/#{board.id}/columns/#{column.id}.json"

      expect(response.status).to eq(204)
      expect(Boards::Column.exists?(column.id)).to eq(false)
    end

    it "rejects users who cannot manage the board" do
      sign_in(outsider)

      delete "/boards/api/boards/#{board.id}/columns/#{column.id}.json"

      expect(response.status).to eq(403)
    end

    it "returns not found when the board does not exist" do
      sign_in(manager)

      delete "/boards/api/boards/0/columns/#{column.id}.json"

      expect(response.status).to eq(404)
    end

    it "returns not found when the column does not exist" do
      sign_in(manager)

      delete "/boards/api/boards/#{board.id}/columns/0.json"

      expect(response.status).to eq(404)
    end
  end
end
