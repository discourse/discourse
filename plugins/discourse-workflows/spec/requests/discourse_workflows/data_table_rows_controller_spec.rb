# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableRowsController do
  fab!(:admin)
  fab!(:user)
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  before { sign_in(admin) }

  shared_examples "requires admin" do |method, path_proc, params_proc = nil|
    it "returns 404 when not logged in" do
      sign_in(Fabricate(:anonymous))
      public_send(
        method,
        instance_exec(&path_proc),
        params: params_proc&.then { instance_exec(&_1) },
      )
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when not admin" do
      sign_in(user)
      public_send(
        method,
        instance_exec(&path_proc),
        params: params_proc&.then { instance_exec(&_1) },
      )
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com") }

    include_examples "requires admin",
                     :get,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
                     end

    it "lists rows" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["rows"].length).to eq(1)
      expect(json["rows"][0]["email"]).to eq("test@test.com")
      expect(json["count"]).to eq(1)
    end

    it "filters rows" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
          params: {
            filter: {
              type: "and",
              filters: [{ columnName: "email", condition: "eq", value: "nope@test.com" }],
            },
          }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["rows"].length).to eq(0)
    end

    it "returns 400 for an invalid filter" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
          params: {
            filter: {
              type: "and",
              filters: [{ columnName: "email", condition: "invalid", value: "test@test.com" }],
            },
          }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    include_examples "requires admin",
                     :post,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
                     end,
                     -> { { data: { email: "a@b.com" } } }

    it "inserts a row" do
      post "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
           params: {
             data: {
               email: "new@test.com",
             },
           }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["row"]["email"]).to eq("new@test.com")
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    include_examples "requires admin",
                     :put,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
                     end,
                     -> { { data: { score: 99 } } }

    it "updates matching rows" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
          params: {
            filter: {
              type: "and",
              filters: [{ columnName: "email", condition: "eq", value: "up@test.com" }],
            },
            data: {
              score: 99,
            },
          }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["updated_count"]).to eq(1)
      expect(find_data_table_row(data_table, row["id"])["score"]).to eq(99)
    end

    it "returns 422 when no rows match" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
          params: {
            filter: {
              type: "and",
              filters: [{ columnName: "email", condition: "eq", value: "missing@test.com" }],
            },
            data: {
              score: 99,
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "del@test.com") }
    fab!(:row_1) { insert_data_table_row(data_table, "email" => "one@test.com") }
    fab!(:row_2) { insert_data_table_row(data_table, "email" => "two@test.com") }

    include_examples "requires admin",
                     :delete,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
                     end

    it "deletes matching rows by filter" do
      row_id = row["id"]
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
             params: {
               filter: {
                 type: "and",
                 filters: [{ columnName: "email", condition: "eq", value: "del@test.com" }],
               },
             }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["deleted_count"]).to eq(1)
      expect(find_data_table_row(data_table, row_id)).to be_nil
    end

    it "bulk deletes rows by ids" do
      id_1 = row_1["id"]
      id_2 = row_2["id"]
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
             params: {
               row_ids: [id_1, id_2],
             }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["deleted_count"]).to eq(2)
      expect(find_data_table_row(data_table, id_1)).to be_nil
      expect(find_data_table_row(data_table, id_2)).to be_nil
    end

    it "returns 404 for non-existent data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/999999/rows.json",
             params: {
               row_ids: [row_1["id"]],
             }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 when no target is provided" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json", params: {}
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id/rows/:row_id" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "cell@test.com", "score" => 1) }

    include_examples "requires admin",
                     :put,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row["id"]}.json"
                     end,
                     -> { { data: { score: 1 } } }

    it "updates a single row by id" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row["id"]}.json",
          params: {
            data: {
              score: 42,
            },
          }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["row"]["score"]).to eq(42)
      expect(find_data_table_row(data_table, row["id"])["email"]).to eq("cell@test.com")
    end

    it "returns 404 for non-existent row" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/999999.json",
          params: {
            data: {
              score: 1,
            },
          }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent data table" do
      put "/admin/plugins/discourse-workflows/data-tables/999999/rows/#{row["id"]}.json",
          params: {
            data: {
              score: 1,
            },
          }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id/rows/:row_id" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "gone@test.com") }

    include_examples "requires admin",
                     :delete,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row["id"]}.json"
                     end

    it "deletes a single row by id" do
      row_id = row["id"]
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row_id}.json"
      expect(response).to have_http_status(:no_content)
      expect(find_data_table_row(data_table, row_id)).to be_nil
    end

    it "returns 404 for non-existent row" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/999999.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/999999/rows/#{row["id"]}.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
