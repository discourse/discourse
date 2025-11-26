# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiPersonasController do
  fab!(:admin)
  fab!(:ai_persona)
  fab!(:embedding_definition)
  fab!(:llm_model)

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    SiteSetting.ai_embeddings_enabled = true
  end

  describe "GET #index" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-personas.json"
      expect(response).to be_successful

      expect(response.parsed_body["ai_personas"].length).to eq(AiPersona.count)
      expect(response.parsed_body["meta"]["tools"].length).to eq(
        DiscourseAi::Personas::Persona.all_available_tools.length,
      )
    end

    it "sideloads llms" do
      get "/admin/plugins/discourse-ai/ai-personas.json"
      expect(response).to be_successful

      expect(response.parsed_body["meta"]["llms"]).to eq(
        [
          {
            id: llm_model.id,
            name: llm_model.display_name,
            vision_enabled: llm_model.vision_enabled,
          }.stringify_keys,
        ],
      )
    end

    it "returns tool options with each tool" do
      persona1 = Fabricate(:ai_persona, name: "search1", tools: ["SearchCommand"])
      persona2 =
        Fabricate(
          :ai_persona,
          name: "search2",
          tools: [["SearchCommand", { base_query: "test" }, true]],
          allow_topic_mentions: true,
          allow_personal_messages: true,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          default_llm_id: llm_model.id,
          question_consolidator_llm_id: llm_model.id,
          forced_tool_count: 2,
        )
      persona2.create_user!

      get "/admin/plugins/discourse-ai/ai-personas.json"
      expect(response).to be_successful

      serializer_persona1 = response.parsed_body["ai_personas"].find { |p| p["id"] == persona1.id }
      serializer_persona2 = response.parsed_body["ai_personas"].find { |p| p["id"] == persona2.id }

      expect(serializer_persona2["allow_topic_mentions"]).to eq(true)
      expect(serializer_persona2["allow_personal_messages"]).to eq(true)
      expect(serializer_persona2["allow_chat_channel_mentions"]).to eq(true)
      expect(serializer_persona2["allow_chat_direct_messages"]).to eq(true)

      expect(serializer_persona2["default_llm_id"]).to eq(llm_model.id)
      expect(serializer_persona2["question_consolidator_llm_id"]).to eq(llm_model.id)
      expect(serializer_persona2["user_id"]).to eq(persona2.user_id)
      expect(serializer_persona2["user"]["id"]).to eq(persona2.user_id)
      expect(serializer_persona2["forced_tool_count"]).to eq(2)

      tools = response.parsed_body["meta"]["tools"]
      search_tool = tools.find { |c| c["id"] == "Search" }

      expect(search_tool["help"]).to eq(I18n.t("discourse_ai.ai_bot.tool_help.search"))

      expect(search_tool["options"]).to eq(
        {
          "base_query" => {
            "type" => "string",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.base_query.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.base_query.description"),
          },
          "max_results" => {
            "type" => "integer",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.max_results.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.max_results.description"),
          },
          "search_private" => {
            "type" => "boolean",
            "name" => I18n.t("discourse_ai.ai_bot.tool_options.search.search_private.name"),
            "description" =>
              I18n.t("discourse_ai.ai_bot.tool_options.search.search_private.description"),
          },
        },
      )

      expect(serializer_persona1["tools"]).to eq(["SearchCommand"])
      expect(serializer_persona2["tools"]).to eq(
        [["SearchCommand", { "base_query" => "test" }, true]],
      )
    end

    context "with translations" do
      before do
        SiteSetting.default_locale = "fr"

        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.personas.general.name",
          "Général",
        )
        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.personas.general.description",
          "Général Description",
        )
      end

      after do
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.personas.general.name",
        )
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.personas.general.description",
        )
      end

      it "returns localized persona names and descriptions" do
        get "/admin/plugins/discourse-ai/ai-personas.json"

        id = DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::General]
        persona = response.parsed_body["ai_personas"].find { |p| p["id"] == id }

        expect(persona["name"]).to eq("Général")
        expect(persona["description"]).to eq("Général Description")
      end
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}/edit.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_persona"]["name"]).to eq(ai_persona.name)
    end

    it "includes rag uploads for each persona" do
      upload = Fabricate(:upload)
      RagDocumentFragment.link_target_and_uploads(ai_persona, [upload.id])

      get "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}/edit.json"
      expect(response).to be_successful

      serialized_persona = response.parsed_body["ai_persona"]

      expect(serialized_persona.dig("rag_uploads", 0, "id")).to eq(upload.id)
      expect(serialized_persona.dig("rag_uploads", 0, "original_filename")).to eq(
        upload.original_filename,
      )
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) do
        {
          name: "superbot",
          description: "Assists with tasks",
          system_prompt: "you are a helpful bot",
          tools: [["search", { "base_query" => "test" }, true]],
          top_p: 0.1,
          temperature: 0.5,
          allow_topic_mentions: true,
          allow_personal_messages: true,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          default_llm_id: llm_model.id,
          question_consolidator_llm_id: llm_model.id,
          forced_tool_count: 2,
          response_format: [{ key: "summary", type: "string" }],
          examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        }
      end

      it "creates a new AiPersona" do
        expect {
          post "/admin/plugins/discourse-ai/ai-personas.json",
               params: { ai_persona: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }

          expect(response).to be_successful
          persona_json = response.parsed_body["ai_persona"]

          expect(persona_json["name"]).to eq("superbot")
          expect(persona_json["top_p"]).to eq(0.1)
          expect(persona_json["temperature"]).to eq(0.5)
          expect(persona_json["default_llm_id"]).to eq(llm_model.id)
          expect(persona_json["forced_tool_count"]).to eq(2)
          expect(persona_json["allow_topic_mentions"]).to eq(true)
          expect(persona_json["allow_personal_messages"]).to eq(true)
          expect(persona_json["allow_chat_channel_mentions"]).to eq(true)
          expect(persona_json["allow_chat_direct_messages"]).to eq(true)
          expect(persona_json["question_consolidator_llm_id"]).to eq(llm_model.id)
          expect(persona_json["response_format"].map { |rf| rf["key"] }).to contain_exactly(
            "summary",
          )
          expect(persona_json["examples"]).to eq(valid_attributes[:examples])

          persona = AiPersona.find(persona_json["id"])

          expect(persona.tools).to eq([["search", { "base_query" => "test" }, true]])
          expect(persona.top_p).to eq(0.1)
          expect(persona.temperature).to eq(0.5)
        }.to change(AiPersona, :count).by(1)
      end

      it "logs staff action when creating a persona" do
        # Create the persona
        post "/admin/plugins/discourse-ai/ai-personas.json",
             params: { ai_persona: valid_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to be_successful

        # Now verify the log was created with the right subject
        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "create_ai_persona",
          ).last
        expect(history).to be_present
        expect(history.subject).to eq("superbot") # Verify subject is set to name
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new ai_persona" do
        post "/admin/plugins/discourse-ai/ai-personas.json", params: { ai_persona: { foo: "" } } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "POST #create_user" do
    it "creates a user for the persona" do
      post "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}/create-user.json"
      ai_persona.reload

      expect(response).to be_successful
      expect(response.parsed_body["user"]["id"]).to eq(ai_persona.user_id)
    end
  end

  describe "PUT #update" do
    context "with scoped api key" do
      it "allows updates with a properly scoped API key" do
        api_key = Fabricate(:api_key, user: admin, created_by: admin)

        scope =
          ApiKeyScope.create!(
            resource: "discourse_ai",
            action: "update_personas",
            api_key_id: api_key.id,
            allowed_parameters: {
            },
          )

        put "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "UpdatedByAPI",
                description: "Updated via API key",
              },
            },
            headers: {
              "Api-Key" => api_key.key,
              "Api-Username" => admin.username,
            }

        expect(response).to have_http_status(:ok)
        ai_persona.reload
        expect(ai_persona.name).to eq("UpdatedByAPI")
        expect(ai_persona.description).to eq("Updated via API key")

        scope.update!(action: "fake")

        put "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "UpdatedByAPI 2",
                description: "Updated via API key",
              },
            },
            headers: {
              "Api-Key" => api_key.key,
              "Api-Username" => admin.username,
            }

        expect(response).not_to have_http_status(:ok)
      end
    end

    it "allows us to trivially clear top_p and temperature" do
      persona = Fabricate(:ai_persona, name: "test_bot2", top_p: 0.5, temperature: 0.1)
      put "/admin/plugins/discourse-ai/ai-personas/#{persona.id}.json",
          params: {
            ai_persona: {
              top_p: "",
              temperature: "",
            },
          }

      expect(response).to have_http_status(:ok)
      persona.reload

      expect(persona.top_p).to eq(nil)
      expect(persona.temperature).to eq(nil)
    end

    it "logs staff action when updating a persona" do
      persona = Fabricate(:ai_persona, name: "original_name", description: "original description")

      # Update the persona
      put "/admin/plugins/discourse-ai/ai-personas/#{persona.id}.json",
          params: {
            ai_persona: {
              name: "updated_name",
              description: "updated description",
            },
          }

      expect(response).to have_http_status(:ok)
      persona.reload
      expect(persona.name).to eq("updated_name")
      expect(persona.description).to eq("updated description")

      # Now verify the log was created with the right subject
      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_persona",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("updated_name") # Verify subject is set to the new name
    end

    it "supports updating rag params" do
      persona = Fabricate(:ai_persona, name: "test_bot2")

      put "/admin/plugins/discourse-ai/ai-personas/#{persona.id}.json",
          params: {
            ai_persona: {
              rag_chunk_tokens: "102",
              rag_chunk_overlap_tokens: "12",
              rag_conversation_chunks: "13",
              rag_llm_model_id: llm_model.id,
              question_consolidator_llm_id: llm_model.id,
            },
          }

      expect(response).to have_http_status(:ok)
      persona.reload

      expect(persona.rag_chunk_tokens).to eq(102)
      expect(persona.rag_chunk_overlap_tokens).to eq(12)
      expect(persona.rag_conversation_chunks).to eq(13)
      expect(persona.rag_llm_model_id).to eq(llm_model.id)
      expect(persona.question_consolidator_llm_id).to eq(llm_model.id)
    end

    it "supports updating vision params" do
      persona = Fabricate(:ai_persona, name: "test_bot2")
      put "/admin/plugins/discourse-ai/ai-personas/#{persona.id}.json",
          params: {
            ai_persona: {
              vision_enabled: true,
              vision_max_pixels: 512 * 512,
            },
          }

      expect(response).to have_http_status(:ok)
      persona.reload

      expect(persona.vision_enabled).to eq(true)
      expect(persona.vision_max_pixels).to eq(512 * 512)
    end

    it "does not allow temperature and top p changes on stock personas" do
      put "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json",
          params: {
            ai_persona: {
              top_p: 0.5,
              temperature: 0.1,
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "with valid params" do
      it "updates the requested ai_persona" do
        put "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "SuperBot",
                enabled: false,
                tools: ["search"],
              },
            }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        ai_persona.reload
        expect(ai_persona.name).to eq("SuperBot")
        expect(ai_persona.enabled).to eq(false)
        expect(ai_persona.tools).to eq([["search", nil, false]])
      end
    end

    context "with system personas" do
      it "does not allow editing of system prompts" do
        put "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json",
            params: {
              ai_persona: {
                system_prompt: "you are not a helpful bot",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of tools" do
        put "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json",
            params: {
              ai_persona: {
                tools: %w[SearchCommand ImageCommand],
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of name and description cause it is localized" do
        put "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json",
            params: {
              ai_persona: {
                name: "bob",
                description: "the bob",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does allow some actions" do
        put "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json",
            params: {
              ai_persona: {
                allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_1]],
                enabled: false,
                priority: 989,
              },
            }

        expect(response).to be_successful
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the ai_persona" do
        put "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json",
            params: {
              ai_persona: {
                name: "",
              },
            } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "GET #export" do
    fab!(:ai_tool) do
      AiTool.create!(
        name: "Test Tool",
        tool_name: "test_tool",
        description: "A test tool",
        script: "function invoke(params) { return 'test'; }",
        parameters: [{ name: "query", type: "string", required: true }],
        summary: "Test tool summary",
        created_by_id: admin.id,
      )
    end

    fab!(:persona_with_tools) do
      AiPersona.create!(
        name: "ToolMaster",
        description: "A persona with custom tools",
        system_prompt: "You are a tool master",
        tools: [
          ["SearchCommand", { "base_query" => "test" }, true],
          ["custom-#{ai_tool.id}", { "max_results" => 10 }, false],
        ],
        temperature: 0.8,
        top_p: 0.9,
        response_format: [{ type: "string", key: "summary" }],
        examples: [["user example", "assistant example"]],
        default_llm_id: llm_model.id,
      )
    end

    it "exports a persona as JSON" do
      get "/admin/plugins/discourse-ai/ai-personas/#{persona_with_tools.id}/export.json"

      expect(response).to be_successful
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("toolmaster.json")

      json = response.parsed_body
      expect(json["meta"]["version"]).to eq("1.0")
      expect(json["meta"]["exported_at"]).to be_present

      persona_data = json["persona"]
      expect(persona_data["name"]).to eq("ToolMaster")
      expect(persona_data["description"]).to eq("A persona with custom tools")
      expect(persona_data["system_prompt"]).to eq("You are a tool master")
      expect(persona_data["temperature"]).to eq(0.8)
      expect(persona_data["top_p"]).to eq(0.9)
      expect(persona_data["response_format"]).to eq([{ "type" => "string", "key" => "summary" }])
      expect(persona_data["examples"]).to eq([["user example", "assistant example"]])

      # Check that custom tool ID is replaced with tool_name
      expect(persona_data["tools"]).to include(
        ["SearchCommand", { "base_query" => "test" }, true],
        ["custom-test_tool", { "max_results" => 10 }, false],
      )

      # Check custom tools are exported
      expect(json["custom_tools"]).to be_an(Array)
      expect(json["custom_tools"].length).to eq(1)

      custom_tool = json["custom_tools"].first
      expect(custom_tool["identifier"]).to eq("test_tool")
      expect(custom_tool["name"]).to eq("Test Tool")
      expect(custom_tool["description"]).to eq("A test tool")
      expect(custom_tool["script"]).to eq("function invoke(params) { return 'test'; }")
      expect(custom_tool["parameters"]).to eq(
        [{ "name" => "query", "type" => "string", "required" => true }],
      )
    end

    it "handles personas without custom tools" do
      persona = Fabricate(:ai_persona, tools: ["SearchCommand"])

      get "/admin/plugins/discourse-ai/ai-personas/#{persona.id}/export.json"

      expect(response).to be_successful
      json = response.parsed_body
      expect(json["custom_tools"]).to eq([])
      expect(json["persona"]["tools"]).to eq(["SearchCommand"])
    end

    it "returns 404 for non-existent persona" do
      get "/admin/plugins/discourse-ai/ai-personas/999999/export.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST #import" do
    let(:valid_import_data) do
      {
        meta: {
          version: "1.0",
          exported_at: Time.zone.now.iso8601,
        },
        persona: {
          name: "ImportedPersona",
          description: "An imported persona",
          system_prompt: "You are an imported assistant",
          temperature: 0.7,
          top_p: 0.8,
          response_format: [{ type: "string", key: "answer" }],
          examples: [["hello", "hi there"]],
          tools: ["SearchCommand", ["ReadCommand", { max_length: 1000 }, true]],
        },
        custom_tools: [],
      }
    end

    it "imports a new persona successfully" do
      expect {
        post "/admin/plugins/discourse-ai/ai-personas/import.json",
             params: valid_import_data,
             as: :json
        expect(response).to have_http_status(:created)
      }.to change(AiPersona, :count).by(1)

      persona = AiPersona.find_by(name: "ImportedPersona")
      expect(persona).to be_present
      expect(persona.description).to eq("An imported persona")
      expect(persona.system_prompt).to eq("You are an imported assistant")
      expect(persona.temperature).to eq(0.7)
      expect(persona.top_p).to eq(0.8)
      expect(persona.response_format).to eq([{ "type" => "string", "key" => "answer" }])
      expect(persona.examples).to eq([["hello", "hi there"]])
      expect(persona.tools).to eq(
        ["SearchCommand", ["ReadCommand", { "max_length" => 1000 }, true]],
      )
    end

    it "imports a persona with custom tools" do
      import_data_with_tools = valid_import_data.deep_dup
      import_data_with_tools[:persona][:tools] = [
        "SearchCommand",
        ["custom-my_custom_tool", { param1: "value1" }, false],
      ]
      import_data_with_tools[:custom_tools] = [
        {
          identifier: "my_custom_tool",
          name: "My Custom Tool",
          description: "A custom tool for testing",
          tool_name: "my_custom_tool",
          parameters: [{ name: "param1", type: "string", required: true }],
          summary: "Custom tool summary",
          script: "function invoke(params) { return params.param1; }",
        },
      ]

      expect {
        post "/admin/plugins/discourse-ai/ai-personas/import.json",
             params: import_data_with_tools,
             as: :json
      }.to change(AiPersona, :count).by(1).and change(AiTool, :count).by(1)

      expect(response).to have_http_status(:created)

      persona = AiPersona.find_by(name: "ImportedPersona")
      expect(persona).to be_present

      tool = AiTool.find_by(tool_name: "my_custom_tool")
      expect(tool).to be_present
      expect(tool.name).to eq("My Custom Tool")
      expect(tool.description).to eq("A custom tool for testing")
      expect(tool.script).to eq("function invoke(params) { return params.param1; }")

      # Check that the tool reference uses the ID
      expect(persona.tools).to include(
        "SearchCommand",
        ["custom-#{tool.id}", { "param1" => "value1" }, false],
      )
    end

    it "prevents importing duplicate personas by default" do
      _existing_persona = Fabricate(:ai_persona, name: "ImportedPersona")

      post "/admin/plugins/discourse-ai/ai-personas/import.json",
           params: valid_import_data,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("ImportedPersona")
    end

    it "allows overwriting existing personas with force=true" do
      existing_persona =
        Fabricate(:ai_persona, name: "ImportedPersona", description: "Old description")

      import_data = valid_import_data.merge(force: true)

      expect {
        post "/admin/plugins/discourse-ai/ai-personas/import.json", params: import_data, as: :json
      }.not_to change(AiPersona, :count)

      expect(response).to have_http_status(:ok)

      existing_persona.reload
      expect(existing_persona.description).to eq("An imported persona")
      expect(existing_persona.system_prompt).to eq("You are an imported assistant")
    end

    it "handles invalid import data gracefully" do
      invalid_data = { invalid: "data" }

      post "/admin/plugins/discourse-ai/ai-personas/import.json", params: invalid_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "handles missing persona data" do
      invalid_data = { meta: { version: "1.0" } }

      post "/admin/plugins/discourse-ai/ai-personas/import.json", params: invalid_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "logs staff action when importing a new persona" do
      post "/admin/plugins/discourse-ai/ai-personas/import.json",
           params: valid_import_data,
           as: :json

      expect(response).to have_http_status(:created)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_persona",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("ImportedPersona")
    end

    it "logs staff action when updating an existing persona" do
      _existing_persona = Fabricate(:ai_persona, name: "ImportedPersona")

      import_data = valid_import_data.merge(force: true)

      post "/admin/plugins/discourse-ai/ai-personas/import.json", params: import_data, as: :json

      expect(response).to have_http_status(:ok)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_persona",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("ImportedPersona")
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_persona" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(AiPersona, :count).by(-1)
    end

    it "logs staff action when deleting a persona" do
      # Capture persona details before deletion
      _persona_id = ai_persona.id
      persona_name = ai_persona.name

      # Delete the persona
      delete "/admin/plugins/discourse-ai/ai-personas/#{ai_persona.id}.json"
      expect(response).to have_http_status(:no_content)

      # Now verify the log was created with the right subject
      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_persona",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq(persona_name) # Verify subject is set to name
    end

    it "is not allowed to delete system personas" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::Personas::Persona.system_personas.values.first}.json"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        # let's make sure this is translated
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      }.not_to change(AiPersona, :count)
    end
  end

  describe "#stream_reply" do
    fab!(:llm) { Fabricate(:llm_model, name: "fake_llm", provider: "fake") }
    let(:fake_endpoint) { DiscourseAi::Completions::Endpoints::Fake }

    before { fake_endpoint.delays = [] }

    after { fake_endpoint.reset! }

    it "ensures persona exists" do
      post "/admin/plugins/discourse-ai/ai-personas/stream-reply.json"
      expect(response).to have_http_status(:unprocessable_entity)
      # this ensures localization key is actually in the yaml
      expect(response.body).to include("persona_name")
    end

    it "ensures question exists" do
      ai_persona.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-personas/stream-reply.json",
           params: {
             persona_id: ai_persona.id,
             user_unique_id: "site:test.com:user_id:1",
           }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("query")
    end

    it "ensure persona has a user specified" do
      ai_persona.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-personas/stream-reply.json",
           params: {
             persona_id: ai_persona.id,
             query: "how are you today?",
             user_unique_id: "site:test.com:user_id:1",
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("associated")
    end

    def validate_streamed_response(raw_http, expected)
      lines = raw_http.split("\r\n")

      header_lines, _, payload_lines = lines.chunk { |l| l == "" }.map(&:last)

      preamble = (<<~PREAMBLE).strip
        HTTP/1.1 200 OK
        Content-Type: text/plain; charset=utf-8
        Transfer-Encoding: chunked
        Cache-Control: no-cache, no-store, must-revalidate
        Connection: close
        X-Accel-Buffering: no
        X-Content-Type-Options: nosniff
      PREAMBLE

      expect(header_lines.join("\n")).to eq(preamble)

      parsed = +""

      context_info = nil

      payload_lines.each_slice(2) do |size, data|
        size = size.to_i(16)
        data = data.to_s
        expect(data.bytesize).to eq(size)

        if size > 0
          json = JSON.parse(data)
          parsed << json["partial"].to_s

          context_info = json if json["topic_id"]
        end
      end

      expect(parsed).to eq(expected)

      context_info
    end

    it "is able to create a new conversation" do
      Jobs.run_immediately!
      # trust level 0
      SiteSetting.ai_bot_allowed_groups = "10"

      fake_endpoint.fake_content = ["This is a test! Testing!", "An amazing title"]

      ai_persona.create_user!
      ai_persona.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-personas/stream-reply.json",
           params: {
             persona_name: ai_persona.name,
             query: "how are you today?",
             user_unique_id: "site:test.com:user_id:1",
             preferred_username: "test_user",
             custom_instructions: "To be appended to system prompt",
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      # this is a fake response but it catches errors
      expect(response).to have_http_status(:no_content)

      raw = io_out.read
      context_info = validate_streamed_response(raw, "This is a test! Testing!")

      system_prompt = fake_endpoint.previous_calls[-2][:dialect].prompt.messages.first[:content]

      expect(system_prompt).to eq("you are a helpful bot\nTo be appended to system prompt")

      expect(context_info["topic_id"]).to be_present
      topic = Topic.find(context_info["topic_id"])
      last_post = topic.posts.order(:created_at).last
      expect(last_post.raw).to eq("This is a test! Testing!")

      user_post = topic.posts.find_by(post_number: 1)
      expect(user_post.raw).to eq("how are you today?")

      # need ai persona and user
      expect(topic.topic_allowed_users.count).to eq(2)
      expect(topic.archetype).to eq(Archetype.private_message)
      expect(topic.title).to eq("An amazing title")
      expect(topic.posts.count).to eq(2)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(name: "categories", parameters: {}, id: "tool_1")

      fake_endpoint.fake_content = [tool_call, "this is the response after the tool"]
      # this simplifies function calls
      fake_endpoint.chunk_count = 1

      ai_persona.update!(tools: ["Categories"], show_thinking: true)

      # lets also unstage the user and add the user to tl0
      # this will ensure there are no feedback loops
      new_user = user_post.user
      new_user.update!(staged: false)
      Group.user_trust_level_change!(new_user.id, new_user.trust_level)

      # double check this happened and user is in group
      personas = AiPersona.allowed_modalities(user: new_user.reload, allow_personal_messages: true)
      expect(personas.count).to eq(1)

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-personas/stream-reply.json",
           params: {
             persona_id: ai_persona.id,
             query: "how are you now?",
             user_unique_id: "site:test.com:user_id:1",
             preferred_username: "test_user",
             topic_id: context_info["topic_id"],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      # this is a fake response but it catches errors
      expect(response).to have_http_status(:no_content)

      raw = io_out.read
      context_info = validate_streamed_response(raw, "this is the response after the tool")

      topic = topic.reload
      last_post = topic.posts.order(:created_at).last

      expect(last_post.raw).to end_with("this is the response after the tool")
      # function call is visible in the post
      expect(last_post.raw[0..8]).to eq("<details>")

      user_post = topic.posts.find_by(post_number: 3)
      expect(user_post.raw).to eq("how are you now?")
      expect(user_post.user.username).to eq("test_user")
      expect(user_post.user.custom_fields).to eq(
        { "ai-stream-conversation-unique-id" => "site:test.com:user_id:1" },
      )

      expect(topic.posts.count).to eq(4)
    end
  end
end
