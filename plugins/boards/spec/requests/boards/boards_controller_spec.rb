# frozen_string_literal: true

RSpec.describe Boards::Api::BoardsController do
  fab!(:admin)
  fab!(:reader, :user)
  fab!(:writer, :user)
  fab!(:manager, :user)
  fab!(:outsider, :user)
  fab!(:read_group, :group)
  fab!(:write_group, :group)
  fab!(:manage_group, :group)
  fab!(:category) { Fabricate(:category, name: "General") }

  before do
    enable_current_plugin
    SiteSetting.boards_manage_board_allowed_groups = manage_group.id.to_s
    read_group.add(reader)
    write_group.add(writer)
    manage_group.add(manager)
  end

  describe "GET /boards/api/boards" do
    it "returns only boards visible to the current user" do
      other_group = Fabricate(:group)

      visible = Fabricate(:boards_board, name: "Visible", slug: "visible", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: visible,
        permission: "view",
        groups: [read_group],
      )
      hidden = Fabricate(:boards_board, name: "Hidden", slug: "hidden", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: hidden,
        permission: "view",
        groups: [other_group],
      )

      visible.columns.create!(title: "One", position: 0)

      sign_in(reader)
      get "/boards/api/boards.json"

      expect(response.status).to eq(200)
      slugs = response.parsed_body["boards"].map { |b| b["slug"] }
      expect(slugs).to contain_exactly("visible")
    end

    it "returns all boards for admins" do
      other_group = Fabricate(:group)

      private_board = Fabricate(:boards_board, name: "Private", slug: "private", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: private_board,
        permission: "view",
        groups: [other_group],
      )

      sign_in(admin)
      get "/boards/api/boards.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["boards"].length).to eq(1)
    end

    it "limits boards to the requested permissions" do
      board_editable =
        Fabricate(:boards_board, name: "Editable", slug: "editable", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board_editable,
        permission: "edit",
        groups: [write_group],
      )
      board_view_only =
        Fabricate(:boards_board, name: "View Only", slug: "view-only", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board_view_only,
        permission: "view",
        groups: [write_group],
      )

      sign_in(writer)
      get "/boards/api/boards.json", params: { allowed_permissions: "edit" }

      expect(response.status).to eq(200)
      slugs = response.parsed_body["boards"].map { |b| b["slug"] }
      expect(slugs).to contain_exactly("editable")
    end
  end

  describe "GET /boards/api/boards/available" do
    fab!(:topic)
    fab!(:board) { Fabricate(:boards_board, name: "Product", created_by: admin) }
    fab!(:backlog_column) { Fabricate(:boards_column, board:, title: "Backlog", position: 0) }
    fab!(:done_column) { Fabricate(:boards_column, board:, title: "Done", position: 1) }
    fab!(:topic_card) { Fabricate(:boards_topic_card, board:, column: backlog_column, topic:) }
    fab!(:other_board) { Fabricate(:boards_board, name: "Roadmap", created_by: admin) }
    fab!(:other_column) { Fabricate(:boards_column, board: other_board, title: "Next") }

    before do
      [board, other_board].each do |visible_board|
        Fabricate(
          :access_control_list_with_groups,
          target: visible_board,
          permission: "view",
          groups: [read_group],
        )
      end
    end

    it "returns the topic's board and column memberships" do
      sign_in(reader)

      get "/boards/api/boards/available.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      boards = response.parsed_body["boards"].index_by { |item| item["id"] }

      expect(boards[board.id]["topic_is_member"]).to eq(true)
      expect(
        boards[board.id]["columns"].to_h { |column| [column["id"], column["topic_is_member"]] },
      ).to eq(backlog_column.id => true, done_column.id => false)
      expect(boards[other_board.id]["topic_is_member"]).to eq(false)
      expect(boards[other_board.id]["columns"].sole["topic_is_member"]).to eq(false)
    end

    it "denies access when the user cannot see the topic" do
      private_category = Fabricate(:private_category, group: write_group)
      private_topic = Fabricate(:topic, category: private_category)
      sign_in(reader)

      get "/boards/api/boards/available.json", params: { topic_id: private_topic.id }

      expect(response.status).to eq(403)
    end
  end

  describe "GET /boards/api/boards/:id" do
    it "returns full board payload with columns and cards" do
      topic = Fabricate(:topic, category: category)
      board =
        Fabricate(
          :boards_board,
          name: "Sprint",
          slug: "sprint",
          show_tags: true,
          card_style: "detailed",
          category_ids: [category.id],
          created_by: admin,
        )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )
      col = board.columns.create!(title: "Backlog", position: 0, icon: "list")
      board.cards.create!(
        card_type: :topic,
        topic_id: topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(writer)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      body = response.parsed_body

      board_data = body["board"]
      expect(board_data["name"]).to eq("Sprint")
      expect(board_data["can_write"]).to eq(true)
      expect(board_data["show_tags"]).to eq(true)
      expect(board_data["card_style"]).to eq("detailed")

      columns = body["columns"]
      expect(columns.length).to eq(1)
      expect(columns[0]["title"]).to eq("Backlog")
      expect(columns[0]["icon"]).to eq("list")
      expect(columns[0]["default_sort"]).to eq("priority")
      expect(columns[0]["cards"].length).to eq(1)

      card = columns[0]["cards"][0]
      expect(card["card_type"]).to eq("topic")
      expect(card["topic"]["title"]).to eq(topic.title)
      expect(card["topic"]["slug"]).to eq(topic.slug)
    end

    it "hides restricted board and column tags from users who can read the board" do
      hidden_tag = Fabricate(:tag, name: "security-internal")
      visible_tag = Fabricate(:tag, name: "public-roadmap")
      staff_tag_group =
        Fabricate(:tag_group, name: "Staff Boards Tags", tag_names: [hidden_tag.name])
      staff_tag_group.permissions = [
        [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
      ]
      staff_tag_group.save!

      board =
        Fabricate(
          :boards_board,
          name: "Public Roadmap",
          slug: "public-roadmap",
          tag_ids: [hidden_tag.id, visible_tag.id],
          created_by: admin,
        )
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )
      board.columns.create!(title: "Visible", position: 0, tag_id: visible_tag.id)
      board.columns.create!(title: "Hidden", position: 1, tag_id: hidden_tag.id)

      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      body = response.parsed_body

      expect(body["board"]["tag_ids"]).to contain_exactly(visible_tag.id)
      expect(body["board"]["tag_names"]).to contain_exactly(visible_tag.name)
      expect(body["board"]["columns"].map { |column| column["tag_id"] }).to contain_exactly(
        visible_tag.id,
        nil,
      )
      expect(body["board"]["columns"].map { |column| column["tag_name"] }).to contain_exactly(
        visible_tag.name,
        nil,
      )
      expect(body["columns"].map { |column| column["tag_id"] }).to contain_exactly(
        visible_tag.id,
        nil,
      )
      expect(body["columns"].map { |column| column["tag_name"] }).to contain_exactly(
        visible_tag.name,
        nil,
      )
      expect(response.body).not_to include(hidden_tag.name)
    end

    it "hides restricted tags attached to floater cards from users who can read the board" do
      hidden_tag = Fabricate(:tag, name: "staff-floater")
      visible_tag = Fabricate(:tag, name: "public-floater")
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      board =
        Fabricate(
          :boards_board,
          name: "Public Roadmap",
          slug: "public-roadmap-floaters",
          created_by: admin,
        )
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )
      column = board.columns.create!(title: "Visible", position: 0)
      board.cards.create!(
        card_type: :floater,
        title: "Public card",
        tag_ids: [visible_tag.id, hidden_tag.id],
        column_id: column.id,
        position: 0,
        created_by_id: admin.id,
      )

      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      card = response.parsed_body["columns"].first["cards"].first
      expect(card["tag_ids"]).to contain_exactly(visible_tag.id)
      expect(card["tags"].map { |tag| tag["name"] }).to contain_exactly(visible_tag.name)
      expect(response.body).not_to include(hidden_tag.name)
    end

    it "includes can_manage for users in the manage group" do
      board =
        Fabricate(
          :boards_board,
          name: "Test",
          slug: "test-manage",
          created_by: admin,
          additional_manage_groups: [manage_group],
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(manager)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(true)
    end

    it "includes can_manage for admins" do
      board = Fabricate(:boards_board, name: "Test", slug: "test-admin-manage", created_by: admin)
      board.columns.create!(title: "Col", position: 0)

      sign_in(admin)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(true)
    end

    it "sets can_manage to false for users not in the manage group" do
      board = Fabricate(:boards_board, name: "Test", slug: "test-nomanage", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board.columns.create!(title: "Col", position: 0)

      sign_in(reader)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.parsed_body["board"]["can_manage"]).to eq(false)
    end

    it "includes the creator's username and avatar_template" do
      board =
        Fabricate(:boards_board, name: "Creator Test", slug: "creator-test", created_by: admin)
      board.columns.create!(title: "Col", position: 0)

      sign_in(admin)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      created_by = response.parsed_body["board"]["created_by"]
      expect(created_by).to be_present
      expect(created_by["username"]).to eq(admin.username)
      expect(created_by["avatar_template"]).to eq(admin.avatar_template)
    end

    it "includes topic details for detailed cards" do
      topic = Fabricate(:topic, category: category)
      board =
        Fabricate(
          :boards_board,
          name: "Detailed",
          slug: "detailed",
          card_style: "detailed",
          category_ids: [category.id],
          created_by: admin,
        )
      col = board.columns.create!(title: "Col", position: 0)
      board.cards.create!(
        card_type: :topic,
        topic_id: topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )

      sign_in(admin)
      get "/boards/api/boards/#{board.id}.json"

      topic_data = response.parsed_body["columns"][0]["cards"][0]["topic"]
      expect(topic_data["image_url"]).to be_present.or be_nil
      expect(topic_data).to have_key("last_poster")
      expect(topic_data["bumped_at"]).to be_present
      expect(topic_data["category_id"]).to eq(category.id)
    end

    it "filters out topics the user cannot see" do
      private_category = Fabricate(:private_category, group: write_group)
      visible_topic = Fabricate(:topic, category: category)
      private_topic = Fabricate(:topic, category: private_category)

      board =
        Fabricate(
          :boards_board,
          name: "Mixed",
          slug: "mixed",
          category_ids: [category.id, private_category.id],
          created_by: admin,
        )
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      col = board.columns.create!(title: "Col", position: 0)

      board.cards.create!(
        card_type: :topic,
        topic_id: visible_topic.id,
        column_id: col.id,
        position: 0,
        created_by_id: admin.id,
      )
      board.cards.create!(
        card_type: :topic,
        topic_id: private_topic.id,
        column_id: col.id,
        position: 1,
        created_by_id: admin.id,
      )

      sign_in(reader)
      get "/boards/api/boards/#{board.id}.json"

      card_titles = response.parsed_body["columns"][0]["cards"].map { |c| c["topic"]["title"] }
      expect(card_titles).to include(visible_topic.title)
      expect(card_titles).not_to include(private_topic.title)
    end

    it "does not backfill cards into unconstrained columns even when the board filter matches" do
      topic = Fabricate(:topic, category: category)
      board =
        Fabricate(
          :boards_board,
          name: "Auto Board",
          slug: "auto-board",
          category_ids: [category.id],
          created_by: admin,
        )
      board.columns.create!(title: "Backlog", position: 0)

      sign_in(admin)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(200)
      cards = response.parsed_body["columns"][0]["cards"]
      expect(cards).to eq([])
      expect(board.cards.where(topic_id: topic.id)).to be_blank
    end

    it "orders columns by recency default sort order based on computed recency_at" do
      board =
        Fabricate(:boards_board, name: "Recent Board", slug: "recent-board", created_by: admin)
      col = board.columns.create!(title: "Done", position: 0, default_sort: "recency")
      old_card =
        board.cards.create!(
          card_type: :floater,
          title: "Old",
          column_id: col.id,
          position: 0,
          column_changed_at: 5.days.ago,
          created_by_id: admin.id,
        )
      new_card =
        board.cards.create!(
          card_type: :floater,
          title: "New",
          column_id: col.id,
          position: 10_000,
          column_changed_at: 5.days.ago,
          created_by_id: admin.id,
        )
      old_card.update_columns(updated_at: 4.days.ago)
      new_card.update_columns(updated_at: 1.hour.ago)

      sign_in(admin)
      get "/boards/api/boards/#{board.id}.json"

      card_titles = response.parsed_body["columns"][0]["cards"].map { |card| card["title"] }
      expect(card_titles).to eq(%w[New Old])
      expect(response.parsed_body["columns"][0]["cards"][0]["recency_at"]).to be_present
    end

    it "denies access to users without read permission" do
      board = Fabricate(:boards_board, name: "Secret", slug: "secret", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      board.columns.create!(title: "Col", position: 0)

      sign_in(outsider)
      get "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(403)
    end

    it "reports public_read based on the anonymous group" do
      public_board = Fabricate(:boards_board, name: "Public", slug: "public", created_by: admin)
      Fabricate(
        :access_control_list,
        target: public_board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]],
      )
      public_board.columns.create!(title: "Col", position: 0)

      restricted_board =
        Fabricate(:boards_board, name: "Restricted", slug: "restricted", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: restricted_board,
        permission: "view",
        groups: [read_group],
      )
      restricted_board.columns.create!(title: "Col", position: 0)

      sign_in(admin)

      get "/boards/api/boards/#{public_board.id}.json"
      expect(response.parsed_body["board"]["anonymous_can_read"]).to be_truthy

      get "/boards/api/boards/#{restricted_board.id}.json"
      expect(response.parsed_body["board"]["anonymous_can_read"]).to be_falsey
    end
  end

  describe "POST /boards/api/boards" do
    it "creates a board for users in the manage group" do
      sign_in(manager)

      post "/boards/api/boards.json",
           params: {
             board: {
               name: "Engineering",
               slug: "engineering",
               columns: [{ title: "Backlog" }, { title: "In Progress" }],
             },
           }

      expect(response.status).to eq(201)
      board = Boards::Board.find_by(slug: "engineering")
      expect(board).to be_present
      expect(board.columns.count).to eq(2)
      expect(board.columns.order(:position).pluck(:title)).to eq(["Backlog", "In Progress"])
    end

    it "creates a board for admin users" do
      sign_in(admin)

      post "/boards/api/boards.json",
           params: {
             board: {
               name: "Admin Board",
               slug: "admin-board",
             },
           }

      expect(response.status).to eq(201)
    end

    it "rejects users not in the manage group" do
      sign_in(outsider)

      post "/boards/api/boards.json", params: { board: { name: "Nope", slug: "nope" } }

      expect(response.status).to eq(403)
    end
  end

  describe "PUT /boards/api/boards/:id" do
    it "updates board attributes for users in the manage group" do
      board =
        Fabricate(
          :boards_board,
          name: "Old Name",
          slug: "old-name",
          created_by: admin,
          additional_manage_groups: [manage_group],
        )
      board.columns.create!(title: "Col", position: 0)

      sign_in(manager)

      put "/boards/api/boards/#{board.id}.json",
          params: {
            board: {
              name: "New Name",
              show_tags: true,
              columns: [{ id: board.columns.first.id, title: "Renamed" }],
            },
          }

      expect(response.status).to eq(200)
      board.reload
      expect(board.name).to eq("New Name")
      expect(board.show_tags).to eq(true)
      expect(board.columns.first.title).to eq("Col")
    end

    it "does not update columns when a columns payload is submitted" do
      board =
        Fabricate(
          :boards_board,
          name: "Column Payload",
          slug: "column-payload",
          created_by: admin,
          additional_manage_groups: [manage_group],
        )
      column = board.columns.create!(title: "Col", position: 0)

      sign_in(manager)

      put "/boards/api/boards/#{board.id}.json",
          params: {
            board: {
              name: "Updated",
              columns: [{ id: column.id, title: "Renamed", default_sort: "recency" }],
            },
          }

      expect(response.status).to eq(200)
      expect(column.reload).to have_attributes(title: "Col", default_sort: "priority")
    end

    it "rejects users not in the manage group" do
      board = Fabricate(:boards_board, name: "Protected", slug: "protected", created_by: admin)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )

      sign_in(writer)

      put "/boards/api/boards/#{board.id}.json", params: { board: { name: "Hacked" } }

      expect(response.status).to eq(403)
    end
  end

  describe "POST /boards/api/boards/:id/move-column" do
    fab!(:sales_tag, :tag) { Fabricate(:tag, name: "sales") }
    fab!(:board_mc) do
      board =
        Fabricate(
          :boards_board,
          name: "Move Col",
          slug: "move-col",
          tag_ids: [sales_tag.id],
          created_by: admin,
          additional_manage_groups: [manage_group],
        )
      board
    end
    fab!(:col_a) { board_mc.columns.create!(title: "A", position: 0) }
    fab!(:col_b) { board_mc.columns.create!(title: "B", position: 1) }
    fab!(:col_c) { board_mc.columns.create!(title: "C", position: 2) }

    before { manage_group.add(admin) }

    it "swaps column positions and returns the new order" do
      sign_in(admin)

      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["column_order"]).to eq([col_a.id, col_c.id, col_b.id])
      expect(col_b.reload.position).to eq(2)
      expect(col_c.reload.position).to eq(1)
    end

    it "returns 403 for non-manager users" do
      sign_in(outsider)

      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(403)
    end

    it "returns 403 for anonymous users" do
      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 1,
           }

      expect(response.status).to eq(403)
    end

    it "returns 404 for a nonexistent board" do
      sign_in(admin)

      post "/boards/api/boards/0/move-column.json", params: { column_id: col_b.id, direction: 1 }

      expect(response.status).to eq(404)
    end

    it "returns 404 for a nonexistent column" do
      sign_in(admin)

      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: 0,
             direction: 1,
           }

      expect(response.status).to eq(404)
    end

    it "returns 400 for an invalid direction" do
      sign_in(admin)

      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_b.id,
             direction: 5,
           }

      expect(response.status).to eq(400)
    end

    it "returns 422 when moving past the boundary" do
      sign_in(admin)

      post "/boards/api/boards/#{board_mc.id}/move-column.json",
           params: {
             column_id: col_c.id,
             direction: 1,
           }

      expect(response.status).to eq(422)
    end
  end

  describe "DELETE /boards/api/boards/:id" do
    it "deletes a board for users in the manage group" do
      board =
        Fabricate(
          :boards_board,
          name: "Deletable",
          slug: "deletable",
          created_by: admin,
          additional_manage_groups: [manage_group],
        )

      sign_in(manager)

      expect { delete "/boards/api/boards/#{board.id}.json" }.to change { Boards::Board.count }.by(
        -1,
      )

      expect(response.status).to eq(204)
    end

    it "rejects users not in the manage group" do
      board = Fabricate(:boards_board, name: "Protected", slug: "protected", created_by: admin)

      sign_in(outsider)

      delete "/boards/api/boards/#{board.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
