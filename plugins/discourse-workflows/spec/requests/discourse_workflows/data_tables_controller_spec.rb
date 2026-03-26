# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTablesController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true
    sign_in(admin)
  end

  describe "GET /admin/plugins/discourse-workflows/data-tables" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "lists data tables" do
      get "/admin/plugins/discourse-workflows/data-tables.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["data_tables"].length).to eq(1)
      expect(json["data_tables"][0]["name"]).to eq(data_table.name)
    end

    it "returns meta with total rows" do
      get "/admin/plugins/discourse-workflows/data-tables.json"

      json = response.parsed_body
      expect(json["meta"]["total_rows_data_tables"]).to eq(1)
    end

    it "paginates with cursor param" do
      data_table_2 = Fabricate(:discourse_workflows_data_table, name: "Second")

      get "/admin/plugins/discourse-workflows/data-tables.json",
          params: {
            cursor: data_table_2.id,
            limit: 10,
          }

      json = response.parsed_body
      expect(json["data_tables"].length).to eq(1)
      expect(json["data_tables"][0]["id"]).to eq(data_table.id)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/data-tables/:id" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "returns the data table" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["data_table"]).to include("id" => data_table.id, "name" => data_table.name)
    end

    it "returns 404 for non-existent data table" do
      get "/admin/plugins/discourse-workflows/data-tables/999999.json"
      expect(response.status).to eq(404)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/data-tables" do
    it "creates a data table" do
      post "/admin/plugins/discourse-workflows/data-tables.json",
           params: {
             name: "users",
             columns: [{ "name" => "email", "type" => "string" }],
           }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["data_table"]["name"]).to eq("users")
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "updates a data table" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json",
          params: {
            name: "renamed",
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["data_table"]["name"]).to eq("renamed")
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "deletes a data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json"
      expect(response.status).to eq(204)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com") }

    it "lists rows" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json"
      expect(response.status).to eq(200)
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
      expect(response.status).to eq(200)
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

      expect(response.status).to eq(400)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    it "inserts a row" do
      post "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
           params: {
             data: {
               email: "new@test.com",
             },
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["row"]["email"]).to eq("new@test.com")
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

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
      expect(response.status).to eq(200)
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

      expect(response.status).to eq(422)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id/rows" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "del@test.com") }

    it "deletes matching rows" do
      row_id = row["id"]
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows.json",
             params: {
               filter: {
                 type: "and",
                 filters: [{ columnName: "email", condition: "eq", value: "del@test.com" }],
               },
             }
      expect(response.status).to eq(200)
      expect(response.parsed_body["deleted_count"]).to eq(1)
      expect(find_data_table_row(data_table, row_id)).to be_nil
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id/rows/:row_id" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "cell@test.com", "score" => 1) }

    it "updates a single row by id" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row["id"]}.json",
          params: {
            data: {
              score: 42,
            },
          }
      expect(response.status).to eq(200)
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
      expect(response.status).to eq(404)
    end

    it "returns 404 for non-existent data table" do
      put "/admin/plugins/discourse-workflows/data-tables/999999/rows/#{row["id"]}.json",
          params: {
            data: {
              score: 1,
            },
          }
      expect(response.status).to eq(404)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id/rows/:row_id" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "gone@test.com") }

    it "deletes a single row by id" do
      row_id = row["id"]
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/#{row_id}.json"
      expect(response.status).to eq(204)
      expect(find_data_table_row(data_table, row_id)).to be_nil
    end

    it "returns 404 for non-existent row" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/rows/999999.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 for non-existent data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/999999/rows/#{row["id"]}.json"
      expect(response.status).to eq(404)
    end
  end
end
