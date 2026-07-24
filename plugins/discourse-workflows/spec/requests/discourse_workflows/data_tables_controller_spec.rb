# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTablesController do
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

  describe "GET /admin/plugins/discourse-workflows/data-tables" do
    fab!(:data_table, :discourse_workflows_data_table)

    include_examples "requires admin",
                     :get,
                     -> { "/admin/plugins/discourse-workflows/data-tables.json" }

    it "lists data tables" do
      get "/admin/plugins/discourse-workflows/data-tables.json"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["data_tables"].length).to eq(1)
      expect(json["data_tables"][0]["name"]).to eq(data_table.name)
    end

    it "returns shared pagination meta" do
      data_table_2 = Fabricate(:discourse_workflows_data_table, name: "Second")

      get "/admin/plugins/discourse-workflows/data-tables.json", params: { limit: 1 }

      json = response.parsed_body
      expect(json["meta"]).to include(
        "total_rows" => 2,
        "load_more_url" =>
          "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{data_table_2.id}&limit=1",
      )
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

    include_examples "requires admin",
                     :get,
                     -> { "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json" }

    it "returns the data table" do
      get "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["data_table"]).to include("id" => data_table.id, "name" => data_table.name)
    end

    it "returns 404 for non-existent data table" do
      get "/admin/plugins/discourse-workflows/data-tables/999999.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /admin/plugins/discourse-workflows/data-tables" do
    include_examples "requires admin",
                     :post,
                     -> { "/admin/plugins/discourse-workflows/data-tables.json" },
                     -> { { name: "t" } }

    it "creates a data table" do
      post "/admin/plugins/discourse-workflows/data-tables.json",
           params: {
             name: "users",
             columns: [{ "name" => "email", "type" => "string" }],
           },
           as: :json
      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["data_table"]["name"]).to eq("users")
      expect(json["data_table"]["columns"]).to include(
        include("name" => "email", "type" => "string"),
      )
    end

    it "creates a data table when the modal submits only a name" do
      post "/admin/plugins/discourse-workflows/data-tables.json", params: { name: "empty_table" }

      expect(response).to have_http_status(:created)
      body = response.parsed_body["data_table"]
      expect(body["name"]).to eq("empty_table")
      expect(body["columns"].map { |c| c["name"] }).to eq(%w[id created_at updated_at])
    end
  end

  describe "PUT /admin/plugins/discourse-workflows/data-tables/:id" do
    fab!(:data_table, :discourse_workflows_data_table)

    include_examples "requires admin",
                     :put,
                     -> { "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json" },
                     -> { { name: "t" } }

    it "updates a data table" do
      put "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json",
          params: {
            name: "renamed",
          }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data_table"]["name"]).to eq("renamed")
    end

    it "returns 404 for non-existent data table" do
      put "/admin/plugins/discourse-workflows/data-tables/999999.json", params: { name: "test" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/plugins/discourse-workflows/data-tables/:id" do
    fab!(:data_table, :discourse_workflows_data_table)

    include_examples "requires admin",
                     :delete,
                     -> { "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json" }

    it "deletes a data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json"
      expect(response).to have_http_status(:no_content)
    end

    context "when data table is referenced by a workflow" do
      fab!(:workflow) do
        Fabricate(
          :discourse_workflows_workflow,
          name: "My Workflow",
          created_by: admin,
          nodes: [
            {
              "id" => "data-table-1",
              "type" => "action:data_table",
              "typeVersion" => "1.0",
              "name" => "Data Table",
              "position" => {
                "x" => 0,
                "y" => 0,
              },
              "parameters" => {
                "data_table_id" => data_table.id,
              },
              "credentials" => {
              },
            },
          ],
          connections: {
          },
        )
      end

      before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

      it "returns 422 with referencing workflow details" do
        delete "/admin/plugins/discourse-workflows/data-tables/#{data_table.id}.json"

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["type"]).to eq("data_table_in_use")
        expect(body["referencing_workflows"]).to contain_exactly(
          { "id" => workflow.id, "name" => "My Workflow" },
        )
      end
    end

    it "returns 404 for non-existent data table" do
      delete "/admin/plugins/discourse-workflows/data-tables/999999.json"
      expect(response).to have_http_status(:not_found)
    end
  end
end
