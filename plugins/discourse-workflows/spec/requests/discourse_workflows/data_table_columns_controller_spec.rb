# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumnsController do
  fab!(:admin)
  fab!(:user)

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

  describe "POST /admin/plugins/discourse-workflows/data-tables/:id/columns" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com") }

    include_examples "requires admin",
                     :post,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns.json"
                     end,
                     -> { { name: "c", column_type: "string" } }

    it "creates a column without losing existing rows" do
      post "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns.json",
           params: {
             name: "score",
             column_type: "number",
           }

      expect(response).to have_http_status(:created)
      column_names = response.parsed_body["data_table"]["columns"].map { |column| column["name"] }
      expect(column_names).to include("email", "score")
      expect(find_data_table_row(data_table, row["id"])).to include(
        "email" => "test@test.com",
        "score" => nil,
      )
    end
  end

  describe "PATCH /admin/plugins/discourse-workflows/data-tables/:id/columns/:column_name/rename" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com") }

    include_examples "requires admin",
                     :patch,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns/email/rename.json"
                     end,
                     -> { { name: "renamed" } }

    it "renames a column without losing existing rows" do
      patch "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns/email/rename.json",
            params: {
              name: "contact_email",
            }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data_table"]["columns"]).to include(
        include("name" => "contact_email", "type" => "string"),
      )

      row_data = find_data_table_row(data_table, row["id"])
      expect(row_data["contact_email"]).to eq("test@test.com")
      expect(row_data).not_to have_key("email")
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id/columns/:column_name" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "email", "type" => "string" },
          { "name" => "score", "type" => "number" },
        ],
      )
    end
    fab!(:row) { insert_data_table_row(data_table, "email" => "test@test.com", "score" => 7) }

    include_examples "requires admin",
                     :delete,
                     -> do
                       "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns/email.json"
                     end

    it "deletes the column and preserves remaining row data" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}/columns/email.json"

      expect(response).to have_http_status(:no_content)
      expect(find_data_table_row(data_table, row["id"])).to include("score" => 7)
    end
  end
end
