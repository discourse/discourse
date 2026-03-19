# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiAgentsController do
  fab!(:admin)
  fab!(:admin_2, :admin)
  fab!(:ai_agent)
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
      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      expect(response.parsed_body["ai_agents"].length).to eq(AiAgent.count)
      expect(response.parsed_body["meta"]["tools"].length).to eq(
        DiscourseAi::Agents::Agent.all_available_tools.length,
      )
    end

    it "includes token_count for custom tools" do
      tool =
        AiTool.create!(
          name: "Token Test",
          tool_name: "token_test",
          description: "A test tool",
          parameters: [{ name: "query", type: "string", description: "search query" }],
          script: "function invoke(params) { return 'test'; }",
          summary: "Test",
          created_by_id: admin.id,
          enabled: true,
        )

      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      tools = response.parsed_body["meta"]["tools"]
      custom_tool = tools.find { |t| t["id"] == "custom-#{tool.id}" }
      expect(custom_tool["token_count"]).to be_a(Integer)
      expect(custom_tool["token_count"]).to be > 0
    end

    it "sideloads llms" do
      get "/admin/plugins/discourse-ai/ai-agents.json"
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
      agent1 = Fabricate(:ai_agent, name: "search1", tools: ["SearchCommand"])
      agent2 =
        Fabricate(
          :ai_agent,
          name: "search2",
          tools: [["SearchCommand", { base_query: "test" }, true]],
          allow_topic_mentions: true,
          allow_personal_messages: true,
          allow_chat_channel_mentions: true,
          allow_chat_direct_messages: true,
          default_llm_id: llm_model.id,
          forced_tool_count: 2,
        )
      agent2.create_user!

      get "/admin/plugins/discourse-ai/ai-agents.json"
      expect(response).to be_successful

      serializer_agent1 = response.parsed_body["ai_agents"].find { |p| p["id"] == agent1.id }
      serializer_agent2 = response.parsed_body["ai_agents"].find { |p| p["id"] == agent2.id }

      expect(serializer_agent2["allow_topic_mentions"]).to eq(true)
      expect(serializer_agent2["allow_personal_messages"]).to eq(true)
      expect(serializer_agent2["allow_chat_channel_mentions"]).to eq(true)
      expect(serializer_agent2["allow_chat_direct_messages"]).to eq(true)

      expect(serializer_agent2["default_llm_id"]).to eq(llm_model.id)
      expect(serializer_agent2).not_to have_key("question_consolidator_llm_id")
      expect(serializer_agent2["user_id"]).to eq(agent2.user_id)
      expect(serializer_agent2["user"]["id"]).to eq(agent2.user_id)
      expect(serializer_agent2["forced_tool_count"]).to eq(2)

      tools = response.parsed_body["meta"]["tools"]
      search_tool = tools.find { |c| c["id"] == "Search" }

      expect(search_tool["help"]).to eq(I18n.t("discourse_ai.ai_bot.tool_help.search"))
      expect(search_tool["token_count"]).to be_a(Integer)
      expect(search_tool["token_count"]).to be > 0

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

      expect(serializer_agent1["tools"]).to eq(["SearchCommand"])
      expect(serializer_agent2["tools"]).to eq(
        [["SearchCommand", { "base_query" => "test" }, true]],
      )
    end

    it "includes configured mcp servers in meta" do
      Fabricate(:ai_mcp_server, name: "Jira")
      DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns(
        [{ "name" => "search_issues", "description" => "Search issues" }],
      )

      get "/admin/plugins/discourse-ai/ai-agents.json"

      expect(response).to be_successful
      expect(response.parsed_body["meta"]["mcp_servers"]).to include(
        a_hash_including(
          "name" => "Jira",
          "tool_count" => 1,
          "token_count" => an_instance_of(Integer),
        ),
      )
    end

    it "includes token_count for assigned mcp servers in the serialized agent" do
      server = Fabricate(:ai_mcp_server, name: "Jira")
      ai_agent.ai_mcp_servers << server
      DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns(
        [{ "name" => "search_issues", "description" => "Search issues" }],
      )

      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"

      expect(response).to be_successful
      expect(response.parsed_body.dig("ai_agent", "mcp_servers")).to include(
        a_hash_including(
          "name" => "Jira",
          "tool_count" => 1,
          "token_count" => an_instance_of(Integer),
        ),
      )
    end

    context "with translations" do
      before do
        SiteSetting.default_locale = "fr"

        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.name",
          "Général",
        )
        TranslationOverride.upsert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.description",
          "Général Description",
        )
      end

      after do
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.name",
        )
        TranslationOverride.revert!(
          SiteSetting.default_locale,
          "discourse_ai.ai_bot.agents.general.description",
        )
      end

      it "returns localized agent names and descriptions" do
        get "/admin/plugins/discourse-ai/ai-agents.json"

        id = DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General]
        agent = response.parsed_body["ai_agents"].find { |p| p["id"] == id }

        expect(agent["name"]).to eq("Général")
        expect(agent["description"]).to eq("Général Description")
      end
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_agent"]["name"]).to eq(ai_agent.name)
    end

    it "supports ai-agents edit endpoint and payload root" do
      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"
      expect(response).to be_successful
      expect(response.parsed_body["ai_agent"]["name"]).to eq(ai_agent.name)
    end

    it "includes rag uploads for each agent" do
      upload = Fabricate(:upload)
      RagDocumentFragment.link_target_and_uploads(ai_agent, [upload.id])

      get "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/edit.json"
      expect(response).to be_successful

      serialized_agent = response.parsed_body["ai_agent"]

      expect(serialized_agent.dig("rag_uploads", 0, "id")).to eq(upload.id)
      expect(serialized_agent.dig("rag_uploads", 0, "original_filename")).to eq(
        upload.original_filename,
      )
    end
  end

  describe "POST #create" do
    context "with valid params" do
      let(:valid_attributes) do
        ai_mcp_server = Fabricate(:ai_mcp_server, name: "Jira")
        DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns(
          [{ "name" => "search_issues", "description" => "Search issues" }],
        )

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
          forced_tool_count: 2,
          mcp_server_ids: [ai_mcp_server.id],
          execution_mode: "agentic",
          max_turn_tokens: 5000,
          compression_threshold: 80,
          response_format: [{ key: "summary", type: "string" }],
          examples: [%w[user_msg1 assistant_msg1], %w[user_msg2 assistant_msg2]],
        }
      end

      it "creates a new AiAgent" do
        expect {
          post "/admin/plugins/discourse-ai/ai-agents.json",
               params: { ai_agent: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }

          expect(response).to be_successful
          agent_json = response.parsed_body["ai_agent"]

          expect(agent_json["name"]).to eq("superbot")
          expect(agent_json["top_p"]).to eq(0.1)
          expect(agent_json["temperature"]).to eq(0.5)
          expect(agent_json["default_llm_id"]).to eq(llm_model.id)
          expect(agent_json["forced_tool_count"]).to eq(2)
          expect(agent_json["execution_mode"]).to eq("agentic")
          expect(agent_json["max_turn_tokens"]).to eq(5000)

          expect(agent_json["allow_topic_mentions"]).to eq(true)
          expect(agent_json["allow_personal_messages"]).to eq(true)
          expect(agent_json["allow_chat_channel_mentions"]).to eq(true)
          expect(agent_json["allow_chat_direct_messages"]).to eq(true)
          expect(agent_json).not_to have_key("question_consolidator_llm_id")
          expect(agent_json["response_format"].map { |rf| rf["key"] }).to contain_exactly("summary")
          expect(agent_json["examples"]).to eq(valid_attributes[:examples])

          agent = AiAgent.find(agent_json["id"])

          expect(agent.tools).to eq([["search", { "base_query" => "test" }, true]])
          expect(agent.ai_mcp_servers.pluck(:name)).to eq(["Jira"])
          expect(agent.top_p).to eq(0.1)
          expect(agent.temperature).to eq(0.5)
        }.to change(AiAgent, :count).by(1)
      end

      it "creates with ai_agent payload on ai-agents endpoint" do
        expect {
          post "/admin/plugins/discourse-ai/ai-agents.json",
               params: { ai_agent: valid_attributes }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }

          expect(response).to be_successful
          expect(response.parsed_body.dig("ai_agent", "name")).to eq("superbot")
        }.to change(AiAgent, :count).by(1)
      end

      it "logs staff action when creating a agent" do
        # Create the agent
        post "/admin/plugins/discourse-ai/ai-agents.json",
             params: { ai_agent: valid_attributes }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to be_successful

        # Now verify the log was created with the right subject
        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "create_ai_agent",
          ).last
        expect(history).to be_present
        expect(history.subject).to eq("superbot") # Verify subject is set to name
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new ai_agent" do
        post "/admin/plugins/discourse-ai/ai-agents.json", params: { ai_agent: { foo: "" } } # invalid attribute
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "POST #create_user" do
    it "creates a user for the agent" do
      post "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}/create-user.json"
      ai_agent.reload

      expect(response).to be_successful
      expect(response.parsed_body["user"]["id"]).to eq(ai_agent.user_id)
    end
  end

  describe "PUT #update" do
    context "with scoped api key" do
      it "allows updates with a properly scoped API key" do
        api_key = Fabricate(:api_key, user: admin, created_by: admin)

        scope =
          ApiKeyScope.create!(
            resource: "ai",
            action: "update_agents",
            api_key_id: api_key.id,
            allowed_parameters: {
            },
          )

        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "UpdatedByAPI",
                description: "Updated via API key",
              },
            },
            headers: {
              "Api-Key" => api_key.key,
              "Api-Username" => admin.username,
            }

        expect(response).to have_http_status(:ok)
        ai_agent.reload
        expect(ai_agent.name).to eq("UpdatedByAPI")
        expect(ai_agent.description).to eq("Updated via API key")

        scope.update!(action: "fake")

        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
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
      agent = Fabricate(:ai_agent, name: "test_bot2", top_p: 0.5, temperature: 0.1)
      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              top_p: "",
              temperature: "",
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.top_p).to eq(nil)
      expect(agent.temperature).to eq(nil)
    end

    it "logs staff action when updating a agent" do
      agent = Fabricate(:ai_agent, name: "original_name", description: "original description")

      # Update the agent
      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              name: "updated_name",
              description: "updated description",
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload
      expect(agent.name).to eq("updated_name")
      expect(agent.description).to eq("updated description")

      # Now verify the log was created with the right subject
      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_agent",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("updated_name") # Verify subject is set to the new name
    end

    it "supports updating rag params" do
      agent = Fabricate(:ai_agent, name: "test_bot2")

      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              rag_chunk_tokens: "102",
              rag_chunk_overlap_tokens: "12",
              rag_conversation_chunks: "13",
              rag_llm_model_id: llm_model.id,
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.rag_chunk_tokens).to eq(102)
      expect(agent.rag_chunk_overlap_tokens).to eq(12)
      expect(agent.rag_conversation_chunks).to eq(13)
      expect(agent.rag_llm_model_id).to eq(llm_model.id)
    end

    it "supports updating agentic params" do
      agent = Fabricate(:ai_agent, name: "test_bot2")

      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              execution_mode: "agentic",
              max_turn_tokens: 8000,
              compression_threshold: 75,
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.execution_mode).to eq("agentic")
      expect(agent.max_turn_tokens).to eq(8000)

      expect(agent.compression_threshold).to eq(75)
    end

    it "supports updating vision params" do
      agent = Fabricate(:ai_agent, name: "test_bot2")
      put "/admin/plugins/discourse-ai/ai-agents/#{agent.id}.json",
          params: {
            ai_agent: {
              vision_enabled: true,
              vision_max_pixels: 512 * 512,
            },
          }

      expect(response).to have_http_status(:ok)
      agent.reload

      expect(agent.vision_enabled).to eq(true)
      expect(agent.vision_max_pixels).to eq(512 * 512)
    end

    it "does not allow temperature and top p changes on stock agents" do
      put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
          params: {
            ai_agent: {
              top_p: 0.5,
              temperature: 0.1,
            },
          }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "with valid params" do
      it "updates the requested ai_agent" do
        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
                name: "SuperBot",
                enabled: false,
                tools: ["search"],
              },
            }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")

        ai_agent.reload
        expect(ai_agent.name).to eq("SuperBot")
        expect(ai_agent.enabled).to eq(false)
        expect(ai_agent.tools).to eq([["search", nil, false]])
      end
    end

    context "with system agents" do
      it "does not allow editing of system prompts" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                system_prompt: "you are not a helpful bot",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of tools" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                tools: %w[SearchCommand ImageCommand],
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does not allow editing of name and description cause it is localized" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                name: "bob",
                description: "the bob",
              },
            }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      end

      it "does allow some actions" do
        put "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json",
            params: {
              ai_agent: {
                allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_1]],
                enabled: false,
                priority: 989,
              },
            }

        expect(response).to be_successful
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the ai_agent" do
        put "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json",
            params: {
              ai_agent: {
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

    fab!(:agent_with_tools) do
      AiAgent.create!(
        name: "ToolMaster",
        description: "A agent with custom tools",
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

    it "exports a agent as JSON" do
      get "/admin/plugins/discourse-ai/ai-agents/#{agent_with_tools.id}/export.json"

      expect(response).to be_successful
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("toolmaster.json")

      json = response.parsed_body
      expect(json["meta"]["version"]).to eq("1.0")
      expect(json["meta"]["exported_at"]).to be_present

      agent_data = json["agent"]
      expect(agent_data["name"]).to eq("ToolMaster")
      expect(agent_data["description"]).to eq("A agent with custom tools")
      expect(agent_data["system_prompt"]).to eq("You are a tool master")
      expect(agent_data["temperature"]).to eq(0.8)
      expect(agent_data["top_p"]).to eq(0.9)
      expect(agent_data["response_format"]).to eq([{ "type" => "string", "key" => "summary" }])
      expect(agent_data["examples"]).to eq([["user example", "assistant example"]])

      # Check that custom tool ID is replaced with tool_name
      expect(agent_data["tools"]).to include(
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

    it "handles agents without custom tools" do
      agent = Fabricate(:ai_agent, tools: ["SearchCommand"])

      get "/admin/plugins/discourse-ai/ai-agents/#{agent.id}/export.json"

      expect(response).to be_successful
      json = response.parsed_body
      expect(json["custom_tools"]).to eq([])
      expect(json["agent"]["tools"]).to eq(["SearchCommand"])
    end

    it "returns 404 for non-existent agent" do
      get "/admin/plugins/discourse-ai/ai-agents/999999/export.json"
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
        agent: {
          name: "ImportedAgent",
          description: "An imported agent",
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

    it "imports a new agent successfully" do
      expect {
        post "/admin/plugins/discourse-ai/ai-agents/import.json",
             params: valid_import_data,
             as: :json
        expect(response).to have_http_status(:created)
      }.to change(AiAgent, :count).by(1)

      agent = AiAgent.find_by(name: "ImportedAgent")
      expect(agent).to be_present
      expect(agent.description).to eq("An imported agent")
      expect(agent.system_prompt).to eq("You are an imported assistant")
      expect(agent.temperature).to eq(0.7)
      expect(agent.top_p).to eq(0.8)
      expect(agent.response_format).to eq([{ "type" => "string", "key" => "answer" }])
      expect(agent.examples).to eq([["hello", "hi there"]])
      expect(agent.tools).to eq(["SearchCommand", ["ReadCommand", { "max_length" => 1000 }, true]])
    end

    it "imports a agent with custom tools" do
      import_data_with_tools = valid_import_data.deep_dup
      import_data_with_tools[:agent][:tools] = [
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
        post "/admin/plugins/discourse-ai/ai-agents/import.json",
             params: import_data_with_tools,
             as: :json
      }.to change(AiAgent, :count).by(1).and change(AiTool, :count).by(1)

      expect(response).to have_http_status(:created)

      agent = AiAgent.find_by(name: "ImportedAgent")
      expect(agent).to be_present

      tool = AiTool.find_by(tool_name: "my_custom_tool")
      expect(tool).to be_present
      expect(tool.name).to eq("My Custom Tool")
      expect(tool.description).to eq("A custom tool for testing")
      expect(tool.script).to eq("function invoke(params) { return params.param1; }")

      # Check that the tool reference uses the ID
      expect(agent.tools).to include(
        "SearchCommand",
        ["custom-#{tool.id}", { "param1" => "value1" }, false],
      )
    end

    it "prevents importing duplicate agents by default" do
      _existing_agent = Fabricate(:ai_agent, name: "ImportedAgent")

      post "/admin/plugins/discourse-ai/ai-agents/import.json", params: valid_import_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("ImportedAgent")
    end

    it "allows overwriting existing agents with force=true" do
      existing_agent = Fabricate(:ai_agent, name: "ImportedAgent", description: "Old description")

      import_data = valid_import_data.merge(force: true)

      expect {
        post "/admin/plugins/discourse-ai/ai-agents/import.json", params: import_data, as: :json
      }.not_to change(AiAgent, :count)

      expect(response).to have_http_status(:ok)

      existing_agent.reload
      expect(existing_agent.description).to eq("An imported agent")
      expect(existing_agent.system_prompt).to eq("You are an imported assistant")
    end

    it "overwrites existing custom tools with force=true when importing a new agent" do
      existing_tool =
        Fabricate(
          :ai_tool,
          name: "Old Community Scanner",
          tool_name: "scan_public_discourse_community",
          description: "Old description",
          parameters: [],
          summary: "Old summary",
          script: "function invoke() { return 'old'; }",
        )

      import_data_with_tools = valid_import_data.deep_dup.merge(force: true)
      import_data_with_tools[:agent][:tools] = [
        ["custom-scan_public_discourse_community", { max_results: 20 }, false],
      ]
      import_data_with_tools[:custom_tools] = [
        {
          identifier: "scan_public_discourse_community",
          name: "Community Scanner",
          description: "Scans the public Discourse community",
          tool_name: "scan_public_discourse_community",
          parameters: [{ name: "max_results", type: "integer", required: false }],
          summary: "Returns matching public community topics",
          script: "function invoke(params) { return params.max_results || 10; }",
        },
      ]

      initial_tool_count = AiTool.count

      expect {
        post "/admin/plugins/discourse-ai/ai-agents/import.json",
             params: import_data_with_tools,
             as: :json
      }.to change(AiAgent, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(AiTool.count).to eq(initial_tool_count)

      agent = AiAgent.find_by(name: "ImportedAgent")
      expect(agent).to be_present

      existing_tool.reload
      expect(existing_tool.name).to eq("Community Scanner")
      expect(existing_tool.description).to eq("Scans the public Discourse community")
      expect(existing_tool.summary).to eq("Returns matching public community topics")
      expect(existing_tool.script).to eq(
        "function invoke(params) { return params.max_results || 10; }",
      )

      expect(agent.tools).to eq([["custom-#{existing_tool.id}", { "max_results" => 20 }, false]])
    end

    it "handles invalid import data gracefully" do
      invalid_data = { invalid: "data" }

      post "/admin/plugins/discourse-ai/ai-agents/import.json", params: invalid_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "handles missing agent data" do
      invalid_data = { meta: { version: "1.0" } }

      post "/admin/plugins/discourse-ai/ai-agents/import.json", params: invalid_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "with legacy persona format" do
      let(:legacy_import_data) do
        {
          meta: {
            version: "1.0",
            exported_at: Time.zone.now.iso8601,
          },
          persona: {
            name: "LegacyPersona",
            description: "A legacy persona import",
            system_prompt: "You are a legacy assistant",
            temperature: 0.5,
            top_p: 0.9,
            response_format: [],
            examples: [],
            tools: ["SearchCommand"],
          },
          custom_tools: [],
        }
      end

      it "imports a legacy persona payload" do
        expect {
          post "/admin/plugins/discourse-ai/ai-agents/import.json",
               params: legacy_import_data,
               as: :json
          expect(response).to have_http_status(:created)
        }.to change(AiAgent, :count).by(1)

        agent = AiAgent.find_by(name: "LegacyPersona")
        expect(agent).to be_present
        expect(agent.description).to eq("A legacy persona import")
      end

      it "detects conflicts with legacy persona payload" do
        Fabricate(:ai_agent, name: "LegacyPersona")

        post "/admin/plugins/discourse-ai/ai-agents/import.json",
             params: legacy_import_data,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).to include("LegacyPersona")
      end

      it "overwrites with force=true on legacy persona payload" do
        existing = Fabricate(:ai_agent, name: "LegacyPersona", description: "Old")

        post "/admin/plugins/discourse-ai/ai-agents/import.json",
             params: legacy_import_data.merge(force: true),
             as: :json

        expect(response).to have_http_status(:ok)
        existing.reload
        expect(existing.description).to eq("A legacy persona import")
      end
    end

    it "logs staff action when importing a new agent" do
      post "/admin/plugins/discourse-ai/ai-agents/import.json", params: valid_import_data, as: :json

      expect(response).to have_http_status(:created)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "create_ai_agent",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("ImportedAgent")
    end

    it "logs staff action when updating an existing agent" do
      _existing_agent = Fabricate(:ai_agent, name: "ImportedAgent")

      import_data = valid_import_data.merge(force: true)

      post "/admin/plugins/discourse-ai/ai-agents/import.json", params: import_data, as: :json

      expect(response).to have_http_status(:ok)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "update_ai_agent",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq("ImportedAgent")
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested ai_agent" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(AiAgent, :count).by(-1)
    end

    it "logs staff action when deleting a agent" do
      # Capture agent details before deletion
      _agent_id = ai_agent.id
      agent_name = ai_agent.name

      # Delete the agent
      delete "/admin/plugins/discourse-ai/ai-agents/#{ai_agent.id}.json"
      expect(response).to have_http_status(:no_content)

      # Now verify the log was created with the right subject
      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_agent",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq(agent_name) # Verify subject is set to name
    end

    it "is not allowed to delete system agents" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-agents/#{DiscourseAi::Agents::Agent.system_agents.values.first}.json"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"].join).not_to be_blank
        # let's make sure this is translated
        expect(response.parsed_body["errors"].join).not_to include("en.discourse")
      }.not_to change(AiAgent, :count)
    end
  end

  describe "#stream_reply" do
    fab!(:llm) { Fabricate(:llm_model, name: "fake_llm", provider: "fake") }
    let(:fake_endpoint) { DiscourseAi::Completions::Endpoints::Fake }

    before { fake_endpoint.delays = [] }

    after { fake_endpoint.reset! }

    it "ensures agent exists" do
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json"
      expect(response).to have_http_status(:unprocessable_entity)
      # this ensures localization key is actually in the yaml
      expect(response.body).to include("agent_name")
    end

    it "ensures question exists" do
      ai_agent.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             user_unique_id: "site:test.com:user_id:1",
           }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("query")
    end

    it "ensure agent has a user specified" do
      ai_agent.update!(default_llm_id: llm.id)

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "how are you today?",
             user_unique_id: "site:test.com:user_id:1",
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("associated")
    end

    def parse_streamed_response(raw_http)
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
      chunks = []
      context_info = nil

      payload_lines.each_slice(2) do |size, data|
        size = size.to_i(16)
        data = data.to_s
        expect(data.bytesize).to eq(size)

        if size > 0
          json = JSON.parse(data)
          chunks << json
          parsed << json["partial"].to_s

          context_info = json if json["topic_id"]
        end
      end

      { parsed: parsed, context_info: context_info, chunks: chunks }
    end

    def validate_streamed_response(raw_http, expected)
      response = parse_streamed_response(raw_http)
      expect(response[:parsed]).to eq(expected)
      response[:context_info]
    end

    it "is able to create a new conversation" do
      Jobs.run_immediately!
      # trust level 0
      SiteSetting.ai_bot_allowed_groups = "10"

      fake_endpoint.fake_content = ["This is a test! Testing!", "An amazing title"]

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_name: ai_agent.name,
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

      # need ai agent and user
      expect(topic.topic_allowed_users.count).to eq(2)
      expect(topic.archetype).to eq(Archetype.private_message)
      expect(topic.title).to eq("An amazing title")
      expect(topic.posts.count).to eq(2)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(name: "categories", parameters: {}, id: "tool_1")

      fake_endpoint.fake_content = [tool_call, "this is the response after the tool"]
      # this simplifies function calls
      fake_endpoint.chunk_count = 1

      ai_agent.update!(tools: ["Categories"], show_thinking: true)

      # lets also unstage the user and add the user to tl0
      # this will ensure there are no feedback loops
      new_user = user_post.user
      new_user.update!(staged: false)
      Group.user_trust_level_change!(new_user.id, new_user.trust_level)

      # double check this happened and user is in group
      agents = AiAgent.allowed_modalities(user: new_user.reload, allow_personal_messages: true)
      expect(agents.count).to eq(1)

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
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
      expect(last_post.raw[0..8]).to eq("<details ")
      expect(last_post.raw).to include("ai-thinking")

      user_post = topic.posts.find_by(post_number: 3)
      expect(user_post.raw).to eq("how are you now?")
      expect(user_post.user.username).to eq("test_user")
      expect(user_post.user.custom_fields).to eq(
        { "ai-stream-conversation-unique-id" => "site:test.com:user_id:1" },
      )

      expect(topic.posts.count).to eq(4)
    end

    it "supports custom injected tools with resume tokens" do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "10"

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      fake_endpoint.fake_content = [
        DiscourseAi::Completions::ToolCall.new(
          name: "client_weather",
          parameters: {
            city: "Austin",
          },
          id: "tool_1",
        ),
        "This is the response after a client tool call.",
        "Tool flow title",
      ]
      fake_endpoint.chunk_count = 1

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "What's the weather?",
             user_unique_id: "site:test.com:user_id:42",
             preferred_username: "tool_user",
             custom_tools: [
               {
                 name: "client_weather",
                 description: "Gets weather from the client runtime",
                 parameters: [
                   {
                     name: "city",
                     description: "City to fetch weather for",
                     type: "string",
                     required: true,
                   },
                 ],
               },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)

      parsed = parse_streamed_response(io_out.read)
      context = parsed[:context_info]
      tool_event = parsed[:chunks].find { |chunk| chunk["event"] == "tool_calls" }

      expect(parsed[:parsed]).to eq("")
      expect(context["topic_id"]).to be_present
      expect(tool_event).to be_present
      expect(tool_event.dig("tool_calls", 0, "name")).to eq("client_weather")
      expect(tool_event["resume_token"]).to be_present

      topic = Topic.find(context["topic_id"])
      expect(topic.posts.count).to eq(1)
      expect(topic.posts.first.raw).to eq("What's the weather?")

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: tool_event["resume_token"],
             tool_results: [{ tool_call_id: "tool_1", content: { temperature_c: 23 } }],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)

      resumed = parse_streamed_response(io_out.read)
      expect(resumed[:parsed]).to eq("This is the response after a client tool call.")

      topic.reload
      expect(topic.posts.count).to eq(2)
      expect(topic.posts.order(:created_at).last.raw).to eq(
        "This is the response after a client tool call.",
      )
      expect(topic.title).to eq("Tool flow title")
    end

    it "validates resume requests include tool_results" do
      resume_token = SecureRandom.hex(12)
      Discourse.redis.setex(
        DiscourseAi::AiBot::StreamReplyCustomToolsSession.redis_key(resume_token),
        60,
        { prompt: { messages: [], tools: [] } }.to_json,
      )

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: resume_token,
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("tool_results")
    end

    it "supports parallel tool calls in one completion turn" do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "10"

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      user = Fabricate(:user)
      Group.user_trust_level_change!(user.id, user.trust_level)

      first_post =
        PostCreator.create!(
          user,
          title: "Parallel Tool Topic",
          archetype: Archetype.private_message,
          target_usernames: ai_agent.user.username,
          raw: "Initial context message",
          custom_fields: {
            DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
          },
        )
      topic = first_post.topic

      tool_1 =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_weather",
          parameters: {
            city: "Austin",
          },
          id: "tool_1",
        )

      tool_2 =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_time",
          parameters: {
            timezone: "America/Chicago",
          },
          id: "tool_2",
        )

      fake_endpoint.fake_content = [[tool_1, tool_2], "Parallel tool response finished."]

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             username: user.username,
             topic_id: topic.id,
             query: "Need weather and local time.",
             custom_tools: [
               {
                 name: "client_weather",
                 description: "Gets weather from a client runtime",
                 parameters: [
                   {
                     name: "city",
                     description: "City to fetch weather for",
                     type: "string",
                     required: true,
                   },
                 ],
               },
               {
                 name: "client_time",
                 description: "Gets local time from a client runtime",
                 parameters: [
                   {
                     name: "timezone",
                     description: "IANA timezone string",
                     type: "string",
                     required: true,
                   },
                 ],
               },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)

      parsed = parse_streamed_response(io_out.read)
      tool_event = parsed[:chunks].find { |chunk| chunk["event"] == "tool_calls" }

      expect(parsed[:parsed]).to eq("")
      expect(tool_event).to be_present
      expect(tool_event["tool_calls"].length).to eq(2)
      expect(tool_event["tool_calls"].map { |call| call["id"] }).to contain_exactly(
        "tool_1",
        "tool_2",
      )
      expect(tool_event["resume_token"]).to be_present

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: tool_event["resume_token"],
             tool_results: [
               { tool_call_id: "tool_2", content: { local_time: "10:15" } },
               { tool_call_id: "tool_1", content: { temperature_c: 23 } },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)

      resumed = parse_streamed_response(io_out.read)
      expect(resumed[:parsed]).to eq("Parallel tool response finished.")

      topic.reload
      expect(topic.posts.count).to eq(3)
      expect(topic.posts.order(:created_at).last.raw).to eq("Parallel tool response finished.")
    end

    it "rejects too many custom tools" do
      tools =
        Array.new(21) do |index|
          { name: "tool_#{index}", description: "test tool #{index}", parameters: [] }
        end

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             custom_tools: tools,
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("custom_tools")
    end

    it "rejects ambiguous tool_results params" do
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             tool_result: {
               tool_call_id: "tool_1",
               content: "single",
             },
             tool_results: [{ tool_call_id: "tool_2", content: "plural" }],
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("either tool_results or tool_result")
    end

    it "rejects oversized tool result content" do
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: "ignored-by-validation",
             tool_results: [{ tool_call_id: "tool_1", content: "a" * 103_000 }],
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("at most")
    end

    it "rejects nil tool result content" do
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             tool_results: [{ tool_call_id: "tool_1", content: nil }],
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include("tool_results")
    end

    it "handles resume token TOCTOU expiration during session load" do
      allow(DiscourseAi::AiBot::StreamReplyCustomToolsSession).to receive(
        :resume_state_exists?,
      ).and_call_original
      allow(DiscourseAi::AiBot::StreamReplyCustomToolsSession).to receive(
        :resume_state_exists?,
      ).with("toctou-token").and_return(true)

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: "toctou-token",
             tool_results: [{ tool_call_id: "tool_1", content: { ok: true } }],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)

      parsed = parse_streamed_response(io_out.read)
      error_event = parsed[:chunks].find { |chunk| chunk["event"] == "error" }

      expect(error_event).to be_present
      expect(error_event["error"]).to include("resume_token")
    end

    it "rejects resume tokens from a different admin user" do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "10"

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      fake_endpoint.fake_content = [
        DiscourseAi::Completions::ToolCall.new(
          name: "client_weather",
          parameters: {
            city: "Austin",
          },
          id: "tool_1",
        ),
      ]

      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "Need weather",
             user_unique_id: "site:test.com:user_id:mismatch",
             preferred_username: "mismatch_user",
             custom_tools: [
               {
                 name: "client_weather",
                 description: "Gets weather from the client runtime",
                 parameters: [
                   {
                     name: "city",
                     description: "City to fetch weather for",
                     type: "string",
                     required: true,
                   },
                 ],
               },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      parsed = parse_streamed_response(io_out.read)
      resume_token = parsed[:chunks].find { |chunk| chunk["event"] == "tool_calls" }["resume_token"]

      sign_in(admin_2)
      io_out, io_in = IO.pipe

      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: resume_token,
             tool_results: [{ tool_call_id: "tool_1", content: { temp_c: 22 } }],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      resumed = parse_streamed_response(io_out.read)
      error_event = resumed[:chunks].find { |chunk| chunk["event"] == "error" }

      expect(error_event).to be_present
      expect(error_event["error"]).to include("resume_token")
    end

    it "rejects unexpected tool_call_ids in tool results" do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "10"

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      fake_endpoint.fake_content = [
        DiscourseAi::Completions::ToolCall.new(
          name: "client_weather",
          parameters: {
          },
          id: "tool_1",
        ),
      ]

      io_out, io_in = IO.pipe
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             query: "Need weather",
             user_unique_id: "site:test.com:user_id:unexpected",
             preferred_username: "unexpected_user",
             custom_tools: [
               {
                 name: "client_weather",
                 description: "Gets weather from the client runtime",
                 parameters: [],
               },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      parsed = parse_streamed_response(io_out.read)
      resume_token = parsed[:chunks].find { |chunk| chunk["event"] == "tool_calls" }["resume_token"]

      io_out, io_in = IO.pipe
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: resume_token,
             tool_results: [
               { tool_call_id: "tool_1", content: { ok: true } },
               { tool_call_id: "tool_extra", content: { bad: true } },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      resumed = parse_streamed_response(io_out.read)
      error_event = resumed[:chunks].find { |chunk| chunk["event"] == "error" }

      expect(error_event).to be_present
      expect(error_event["error"]).to include("Unexpected")
    end

    it "supports multi-round tool calling with resume" do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "10"

      ai_agent.create_user!
      ai_agent.update!(
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        system_prompt: "you are a helpful bot",
      )

      user = Fabricate(:user)
      Group.user_trust_level_change!(user.id, user.trust_level)

      first_post =
        PostCreator.create!(
          user,
          title: "Multi Round Tool Topic",
          archetype: Archetype.private_message,
          target_usernames: ai_agent.user.username,
          raw: "Initial context message",
          custom_fields: {
            DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
          },
        )
      topic = first_post.topic

      fake_endpoint.fake_content = [
        DiscourseAi::Completions::ToolCall.new(
          name: "client_weather",
          parameters: {
          },
          id: "tool_1",
        ),
        DiscourseAi::Completions::ToolCall.new(name: "client_time", parameters: {}, id: "tool_2"),
        "Finished after two tool rounds.",
      ]

      io_out, io_in = IO.pipe
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             agent_id: ai_agent.id,
             username: user.username,
             topic_id: topic.id,
             query: "Need weather and time.",
             custom_tools: [
               {
                 name: "client_weather",
                 description: "Gets weather from a client runtime",
                 parameters: [],
               },
               {
                 name: "client_time",
                 description: "Gets local time from a client runtime",
                 parameters: [],
               },
             ],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      first_round = parse_streamed_response(io_out.read)
      first_tool_event = first_round[:chunks].find { |chunk| chunk["event"] == "tool_calls" }

      expect(first_tool_event.dig("tool_calls", 0, "id")).to eq("tool_1")

      io_out, io_in = IO.pipe
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: first_tool_event["resume_token"],
             tool_results: [{ tool_call_id: "tool_1", content: { temp_c: 22 } }],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      second_round = parse_streamed_response(io_out.read)
      second_tool_event = second_round[:chunks].find { |chunk| chunk["event"] == "tool_calls" }

      expect(second_tool_event.dig("tool_calls", 0, "id")).to eq("tool_2")

      io_out, io_in = IO.pipe
      post "/admin/plugins/discourse-ai/ai-agents/stream-reply.json",
           params: {
             resume_token: second_tool_event["resume_token"],
             tool_results: [{ tool_call_id: "tool_2", content: { time: "10:15" } }],
           },
           env: {
             "rack.hijack" => lambda { io_in },
           }

      expect(response).to have_http_status(:no_content)
      final_round = parse_streamed_response(io_out.read)

      expect(final_round[:parsed]).to eq("Finished after two tool rounds.")
      topic.reload
      expect(topic.posts.count).to eq(3)
      expect(topic.posts.order(:created_at).last.raw).to eq("Finished after two tool rounds.")
    end
  end
end
