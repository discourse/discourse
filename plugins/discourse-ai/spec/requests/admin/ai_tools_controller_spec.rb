# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiToolsController do
  fab!(:llm_model)
  fab!(:admin)
  fab!(:ai_tool) do
    AiTool.create!(
      name: "Test Tool",
      tool_name: "test_tool",
      description: "A test tool",
      script: "function invoke(params) { return params; }",
      parameters: [
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
          required: true,
        },
      ],
      summary: "Test tool summary",
      created_by_id: -1,
    )
  end

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.ai_embeddings_enabled = true
  end

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-tools.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_tools"].length).to eq(AiTool.count)
      expect(response.parsed_body["meta"]["presets"].length).to be > 0
      expect(response.parsed_body["meta"]["llms"].length).to be > 0
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/edit.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_tool"]["name"]).to eq(ai_tool.name)
    end
  end

  describe "GET #export" do
    it "returns the ai_tool as JSON attachment" do
      get "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/export.json"

      expect(response).to be_successful
      expect(response.headers["Content-Disposition"]).to eq(
        "attachment; filename=\"#{ai_tool.tool_name}.json\"",
      )
      expect(response.parsed_body["ai_tool"]["name"]).to eq(ai_tool.name)
      expect(response.parsed_body["ai_tool"]["tool_name"]).to eq(ai_tool.tool_name)
      expect(response.parsed_body["ai_tool"]["description"]).to eq(ai_tool.description)
      expect(response.parsed_body["ai_tool"]["parameters"]).to eq(ai_tool.parameters)
    end

    it "returns 404 for non-existent ai_tool" do
      get "/admin/plugins/discourse-ai/ai-tools/99999/export.json"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST #import" do
    let(:import_attributes) do
      {
        name: "Imported Tool",
        tool_name: "imported_tool",
        description: "An imported test tool",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
        script: "function invoke(params) { return params; }",
        summary: "Imported tool summary",
      }
    end

    it "imports a new AI tool successfully" do
      expect {
        post "/admin/plugins/discourse-ai/ai-tools/import.json",
             params: { ai_tool: import_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change(AiTool, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["ai_tool"]["name"]).to eq("Imported Tool")
      expect(response.parsed_body["ai_tool"]["tool_name"]).to eq("imported_tool")
    end

    it "returns conflict error when tool with same tool_name exists without force" do
      _existing_tool =
        AiTool.create!(
          name: "Existing Tool",
          tool_name: "imported_tool",
          description: "Existing tool",
          script: "function invoke(params) { return 'existing'; }",
          summary: "Existing summary",
          created_by_id: admin.id,
        )

      expect {
        post "/admin/plugins/discourse-ai/ai-tools/import.json",
             params: { ai_tool: import_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.not_to change(AiTool, :count)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["errors"]).to include(
        "Tool with tool_name 'imported_tool' already exists. Use force=true to overwrite.",
      )
    end

    it "force updates existing tool when force=true" do
      existing_tool =
        AiTool.create!(
          name: "Existing Tool",
          tool_name: "imported_tool",
          description: "Existing tool",
          script: "function invoke(params) { return 'existing'; }",
          summary: "Existing summary",
          created_by_id: admin.id,
        )

      expect {
        post "/admin/plugins/discourse-ai/ai-tools/import.json?force=true",
             params: { ai_tool: import_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.not_to change(AiTool, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ai_tool"]["name"]).to eq("Imported Tool")
      expect(response.parsed_body["ai_tool"]["description"]).to eq("An imported test tool")

      existing_tool.reload
      expect(existing_tool.name).to eq("Imported Tool")
      expect(existing_tool.description).to eq("An imported test tool")
    end
  end

  describe "POST #create" do
    let(:valid_attributes) do
      {
        name: "Test Tool 1",
        tool_name: "test_tool_1",
        description: "A test tool",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
        script: "function invoke(params) { return params; }",
        summary: "Test tool summary",
      }
    end

    it "creates a new AiTool" do
      expect {
        post "/admin/plugins/discourse-ai/ai-tools.json",
             params: { ai_tool: valid_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change(AiTool, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["ai_tool"]["name"]).to eq("Test Tool 1")
      expect(response.parsed_body["ai_tool"]["tool_name"]).to eq("test_tool_1")
    end

    it "logs the creation with StaffActionLogger" do
      expect {
        post "/admin/plugins/discourse-ai/ai-tools.json",
             params: { ai_tool: valid_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change {
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_tool",
        ).count
      }.by(1)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_tool",
        ).last
      expect(history.details).to include("name: Test Tool 1")
      expect(history.details).to include("tool_name: test_tool_1")
      expect(history.subject).to eq("Test Tool 1") # Verify subject field is included
    end

    context "when the parameter is a enum" do
      it "creates the tool with the correct parameters" do
        attrs = valid_attributes
        attrs[:parameters] = [attrs[:parameters].first.merge(enum: %w[c f])]

        expect {
          post "/admin/plugins/discourse-ai/ai-tools.json",
               params: { ai_tool: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        }.to change(AiTool, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body.dig("ai_tool", "parameters", 0, "enum")).to contain_exactly(
          "c",
          "f",
        )
      end
    end

    context "when enum validation fails" do
      it "fails to create tool with empty enum" do
        attrs = valid_attributes
        attrs[:parameters] = [attrs[:parameters].first.merge(enum: [])]

        expect {
          post "/admin/plugins/discourse-ai/ai-tools.json",
               params: { ai_tool: attrs }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        }.not_to change(AiTool, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to include(match(/enum cannot be empty/))
      end

      it "fails to create tool with duplicate enum values" do
        attrs = valid_attributes
        attrs[:parameters] = [attrs[:parameters].first.merge(enum: %w[c f c])]

        expect {
          post "/admin/plugins/discourse-ai/ai-tools.json",
               params: { ai_tool: attrs }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        }.not_to change(AiTool, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to include(match(/enum values must be unique/))
      end
    end
  end

  describe "PUT #update" do
    it "updates the requested ai_tool" do
      put "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json",
          params: {
            ai_tool: {
              name: "Updated Tool",
            },
          }

      expect(response).to be_successful
      expect(ai_tool.reload.name).to eq("Updated Tool")
    end

    it "logs the update with StaffActionLogger" do
      expect {
        put "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json",
            params: {
              ai_tool: {
                name: "Updated Tool",
                description: "Updated description",
              },
            }
      }.to change {
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_tool",
        ).count
      }.by(1)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_tool",
        ).last
      expect(history.details).to include("tool_id: #{ai_tool.id}")
      expect(history.details).to include("name")
      expect(history.details).to include("description")
      expect(history.subject).to eq("Updated Tool")
    end

    context "when updating an enum parameters" do
      it "updates the enum fixed values" do
        put "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json",
            params: {
              ai_tool: {
                parameters: [
                  {
                    name: "unit",
                    type: "string",
                    description: "the unit of measurement celcius c or fahrenheit f",
                    enum: %w[g d],
                  },
                ],
              },
            }

        expect(response).to be_successful
        expect(ai_tool.reload.parameters.dig(0, "enum")).to contain_exactly("g", "d")
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_tool" do
      expect { delete "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json" }.to change(
        AiTool,
        :count,
      ).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "logs the deletion with StaffActionLogger" do
      tool_id = ai_tool.id

      expect { delete "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}.json" }.to change {
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_tool",
        ).count
      }.by(1)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_tool",
        ).last
      expect(history.details).to include("tool_id: #{tool_id}")
      expect(history.subject).to eq("Test Tool") # Verify subject field is included
    end
  end

  describe "#test" do
    it "runs an existing tool and returns the result" do
      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
           params: {
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("input" => "Hello, World!")
    end

    it "accept changes to the ai_tool parameters that redefine stuff" do
      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
           params: {
             ai_tool: {
               script: "function invoke(params) { return 'hi there'; }",
             },
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["output"]).to eq("hi there")
    end

    it "returns an error for invalid tool_id" do
      post "/admin/plugins/discourse-ai/ai-tools/-1/test.json",
           params: {
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(404)
    end

    it "handles exceptions during tool execution" do
      ai_tool.update!(script: "function invoke(params) { throw new Error('Test error'); }")

      post "/admin/plugins/discourse-ai/ai-tools/#{ai_tool.id}/test.json",
           params: {
             id: ai_tool.id,
             parameters: {
               input: "Hello, World!",
             },
           }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].to_s).to include("Error executing the tool")
    end
  end
end
