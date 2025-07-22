# frozen_string_literal: true

RSpec.describe AiTool do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "bananas are a tasty fruit") }
  fab!(:bot_user) { Discourse.system_user }

  def create_tool(
    parameters: nil,
    script: nil,
    rag_chunk_tokens: nil,
    rag_chunk_overlap_tokens: nil
  )
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters:
        parameters || [{ name: "query", type: "string", description: "perform a search" }],
      script: script || "function invoke(params) { return params; }",
      created_by_id: 1,
      summary: "Test tool summary",
      rag_chunk_tokens: rag_chunk_tokens || 374,
      rag_chunk_overlap_tokens: rag_chunk_overlap_tokens || 10,
    )
  end

  before { enable_current_plugin }

  it "it can run a basic tool" do
    tool = create_tool

    expect(tool.signature).to eq(
      {
        name: tool.tool_name,
        description: "test",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
      },
    )

    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    expect(runner.invoke).to eq("query" => "test")
  end

  it "can base64 encode binary HTTP responses" do
    # Create binary data with all possible byte values (0-255)
    binary_data = (0..255).map(&:chr).join
    expected_base64 = Base64.strict_encode64(binary_data)

    script = <<~JS
      function invoke(params) {
        const result = http.post("https://example.com/binary", {
          body: "test",
          base64Encode: true
        });
        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    stub_request(:post, "https://example.com/binary").to_return(
      status: 200,
      body: binary_data,
      headers: {
      },
    )

    result = runner.invoke

    expect(result).to eq(expected_base64)
    # Verify we can decode back to original binary data
    expect(Base64.strict_decode64(result).bytes).to eq((0..255).to_a)
  end

  it "can base64 encode binary GET responses" do
    # Create binary data with all possible byte values (0-255)
    binary_data = (0..255).map(&:chr).join
    expected_base64 = Base64.strict_encode64(binary_data)

    script = <<~JS
      function invoke(params) {
        const result = http.get("https://example.com/binary", {
          base64Encode: true
        });
        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/binary").to_return(
      status: 200,
      body: binary_data,
      headers: {
      },
    )

    result = runner.invoke

    expect(result).to eq(expected_base64)
    # Verify we can decode back to original binary data
    expect(Base64.strict_decode64(result).bytes).to eq((0..255).to_a)
  end

  it "can perform HTTP requests with various verbs" do
    %i[post put delete patch].each do |verb|
      script = <<~JS
      function invoke(params) {
        result = http.#{verb}("https://example.com/api",
          {
            headers: { TestHeader: "TestValue" },
            body: JSON.stringify({ data: params.data })
          }
        );

        return result.body;
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "data" => "test data" }, llm: nil, bot_user: nil)

      stub_request(verb, "https://example.com/api").with(
        body: "{\"data\":\"test data\"}",
        headers: {
          "Accept" => "*/*",
          "Testheader" => "TestValue",
          "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
        },
      ).to_return(status: 200, body: "Success", headers: {})

      result = runner.invoke

      expect(result).to eq("Success")
    end
  end

  it "can perform GET HTTP requests, with 1 param" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query);
        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/test").with(
      headers: {
        "Accept" => "*/*",
        "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
      },
    ).to_return(status: 200, body: "Hello World", headers: {})

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "is limited to MAX http requests" do
    script = <<~JS
      function invoke(params) {
        let i = 0;
        while (i < 21) {
          http.get("https://example.com/");
          i += 1;
        }
        return "will not happen";
      }
      JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/").to_return(
      status: 200,
      body: "Hello World",
      headers: {
      },
    )

    expect { runner.invoke }.to raise_error(DiscourseAi::Personas::ToolRunner::TooManyRequestsError)
  end

  it "can perform GET HTTP requests" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query,
          { headers: { TestHeader: "TestValue" } }
        );

        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/test").with(
      headers: {
        "Accept" => "*/*",
        "Testheader" => "TestValue",
        "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
      },
    ).to_return(status: 200, body: "Hello World", headers: {})

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "will not timeout on slow HTTP reqs" do
    script = <<~JS
      function invoke(params) {
        result = http.get("https://example.com/" + params.query,
          { headers: { TestHeader: "TestValue" } }
        );

        return result.body;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    stub_request(:get, "https://example.com/test").to_return do
      sleep 0.01
      { status: 200, body: "Hello World", headers: {} }
    end

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    runner.timeout = 10

    result = runner.invoke

    expect(result).to eq("Hello World")
  end

  it "has access to llm truncation tools" do
    script = <<~JS
      function invoke(params) {
        return llm.truncate("Hello World", 1);
      }
    JS

    tool = create_tool(script: script)

    runner = tool.runner({}, llm: llm, bot_user: nil)
    result = runner.invoke

    expect(result).to eq("Hello")
  end

  it "is able to run llm completions" do
    script = <<~JS
      function invoke(params) {
        return llm.generate("question two") + llm.generate(
          { messages: [
            { type: "system", content: "system message" },
            { type: "user", content: "user message" }
          ]}
        );
      }
    JS

    tool = create_tool(script: script)

    result = nil
    prompts = nil
    responses = ["Hello ", "World"]

    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
      runner = tool.runner({}, llm: llm, bot_user: nil)
      result = runner.invoke
      prompts = _prompts
    end

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "system message",
        messages: [{ type: :user, content: "user message" }],
      )
    expect(result).to eq("Hello World")
    expect(prompts[0]).to eq("question two")
    expect(prompts[1]).to eq(prompt)
  end

  it "can timeout slow JS" do
    script = <<~JS
      function invoke(params) {
        while (true) {}
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    runner.timeout = 5

    result = runner.invoke
    expect(result[:error]).to eq("Script terminated due to timeout")
  end

  context "when defining RAG fragments" do
    fab!(:cloudflare_embedding_def)

    before do
      SiteSetting.authorized_extensions = "txt"
      SiteSetting.ai_embeddings_selected_model = cloudflare_embedding_def.id
      SiteSetting.ai_embeddings_enabled = true
      Jobs.run_immediately!
    end

    def create_upload(content, filename)
      upload = nil
      Tempfile.create(filename) do |file|
        file.write(content)
        file.rewind

        upload = UploadCreator.new(file, filename).create_for(Discourse.system_user.id)
      end
      upload
    end

    def stub_embeddings
      # this is a trick, we get ever increasing embeddings, this gives us in turn
      # 100% consistent search results
      @counter = 0
      stub_request(:post, cloudflare_embedding_def.url).to_return(
        status: 200,
        body: lambda { |req| { result: { data: [([@counter += 2] * 1024)] } }.to_json },
        headers: {
        },
      )
    end

    it "allows search within uploads" do
      stub_embeddings

      upload1 = create_upload(<<~TXT, "test.txt")
        1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
      TXT

      upload2 = create_upload(<<~TXT, "test.txt")
        30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50
      TXT

      tool = create_tool(rag_chunk_tokens: 10, rag_chunk_overlap_tokens: 4, script: <<~JS)
        function invoke(params) {
          let result1 = index.search("testing a search", { limit: 1 });
          let result2 = index.search("testing another search", { limit: 3, filenames: ["test.txt"] });

          return [result1, result2];
        }
      JS

      RagDocumentFragment.link_target_and_uploads(tool, [upload1.id, upload2.id])

      result = tool.runner({}, llm: nil, bot_user: nil).invoke

      expected = [
        [{ "fragment" => "44 45 46 47 48 49 50", "metadata" => nil }],
        [
          { "fragment" => "44 45 46 47 48 49 50", "metadata" => nil },
          { "fragment" => "36 37 38 39 40 41 42 43 44 45", "metadata" => nil },
          { "fragment" => "30 31 32 33 34 35 36 37", "metadata" => nil },
        ],
      ]

      expect(result).to eq(expected)

      # will force a reindex
      tool.rag_chunk_tokens = 5
      tool.rag_chunk_overlap_tokens = 2
      tool.save!

      # this part of the API is a bit awkward, maybe we should do it
      # automatically
      RagDocumentFragment.update_target_uploads(tool, [upload1.id, upload2.id])
      result = tool.runner({}, llm: nil, bot_user: nil).invoke

      # this is flaking, it is not critical cause it relies on vector search
      # that may not be 100% deterministic

      # expected = [
      #   [{ "fragment" => "48 49 50", "metadata" => nil }],
      #   [
      #     { "fragment" => "48 49 50", "metadata" => nil },
      #     { "fragment" => "45 46 47", "metadata" => nil },
      #     { "fragment" => "42 43 44", "metadata" => nil },
      #   ],
      # ]

      expect(result.length).to eq(2)
      expect(result[0][0]["fragment"].length).to eq(8)
      expect(result[1].length).to eq(3)
    end
  end

  context "when using the topic API" do
    it "can fetch topic details" do
      script = <<~JS
        function invoke(params) {
          return discourse.getTopic(params.topic_id);
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "topic_id" => topic.id }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result["id"]).to eq(topic.id)
      expect(result["title"]).to eq(topic.title)
      expect(result["archetype"]).to eq("regular")
      expect(result["posts_count"]).to eq(1)
    end
  end

  context "when using the post API" do
    it "can fetch post details" do
      script = <<~JS
        function invoke(params) {
          const post = discourse.getPost(params.post_id);
          return {
            post: post,
            topic: post.topic
          }
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "post_id" => post.id }, llm: nil, bot_user: nil)

      result = runner.invoke
      post_hash = result["post"]
      topic_hash = result["topic"]

      expect(post_hash["id"]).to eq(post.id)
      expect(post_hash["topic_id"]).to eq(topic.id)
      expect(post_hash["raw"]).to eq(post.raw)

      expect(topic_hash["id"]).to eq(topic.id)
    end
  end

  context "when using the search API" do
    before { SearchIndexer.enable }
    after { SearchIndexer.disable }

    it "can perform a discourse search" do
      SearchIndexer.index(topic, force: true)
      SearchIndexer.index(post, force: true)

      script = <<~JS
        function invoke(params) {
          return discourse.search({ search_query: params.query });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "banana" }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result["rows"].length).to be > 0
      expect(result["rows"].first["title"]).to eq(topic.title)
    end
  end

  context "when using the chat API" do
    before(:each) do
      skip "Chat plugin tests skipped because Chat module is not defined." unless defined?(Chat)
      SiteSetting.chat_enabled = true
    end

    fab!(:chat_user) { Fabricate(:user) }
    fab!(:chat_channel) do
      Fabricate(:chat_channel).tap do |channel|
        Fabricate(
          :user_chat_channel_membership,
          user: chat_user,
          chat_channel: channel,
          following: true,
        )
      end
    end

    it "can create a chat message" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_name,
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          {
            "channel_name" => chat_channel.name,
            "username" => chat_user.username,
            "message" => "Hello from the tool!",
          },
          llm: nil,
          bot_user: bot_user, # The user *running* the tool doesn't affect sender
        )

      initial_message_count = Chat::Message.count
      result = runner.invoke

      expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"
      expect(result["message"]).to eq("Hello from the tool!")
      expect(result["created_at"]).to be_present
      expect(result).not_to have_key("error")

      # Verify message was actually created in the database
      expect(Chat::Message.count).to eq(initial_message_count + 1)
      created_message = Chat::Message.find_by(id: result["message_id"])

      expect(created_message).not_to be_nil
      expect(created_message.message).to eq("Hello from the tool!")
      expect(created_message.user_id).to eq(chat_user.id) # Message is sent AS the specified user
      expect(created_message.chat_channel_id).to eq(chat_channel.id)
    end

    it "can create a chat message using channel slug" do
      chat_channel.update!(name: "My Test Channel", slug: "my-test-channel")
      expect(chat_channel.slug).to eq("my-test-channel")

      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_slug, // Using slug here
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          {
            "channel_slug" => chat_channel.slug,
            "username" => chat_user.username,
            "message" => "Hello via slug!",
          },
          llm: nil,
          bot_user: bot_user,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"
      # see: https://github.com/rubyjs/mini_racer/issues/348
      # expect(result["message_id"]).to be_a(Integer)

      created_message = Chat::Message.find_by(id: result["message_id"])
      expect(created_message).not_to be_nil
      expect(created_message.message).to eq("Hello via slug!")
      expect(created_message.chat_channel_id).to eq(chat_channel.id)
    end

    it "returns an error if the channel is not found" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: "non_existent_channel",
            username: params.username,
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "username" => chat_user.username, "message" => "Test" },
          llm: nil,
          bot_user: bot_user,
        )

      initial_message_count = Chat::Message.count
      expect { runner.invoke }.to raise_error(
        MiniRacer::RuntimeError,
        /Channel not found: non_existent_channel/,
      )

      expect(Chat::Message.count).to eq(initial_message_count) # Verify no message created
    end

    it "returns an error if the user is not found" do
      script = <<~JS
        function invoke(params) {
          return discourse.createChatMessage({
            channel_name: params.channel_name,
            username: "non_existent_user",
            message: params.message
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "channel_name" => chat_channel.name, "message" => "Test" },
          llm: nil,
          bot_user: bot_user,
        )

      initial_message_count = Chat::Message.count
      expect { runner.invoke }.to raise_error(
        MiniRacer::RuntimeError,
        /User not found: non_existent_user/,
      )

      expect(Chat::Message.count).to eq(initial_message_count) # Verify no message created
    end
  end

  context "when updating personas" do
    fab!(:ai_persona) do
      Fabricate(:ai_persona, name: "TestPersona", system_prompt: "Original prompt")
    end

    it "can update a persona with proper permissions" do
      script = <<~JS
        function invoke(params) {
          return discourse.updatePersona(params.persona_name, {
            system_prompt: params.new_prompt,
            temperature: 0.7,
            top_p: 0.9
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { persona_name: "TestPersona", new_prompt: "Updated system prompt" },
          llm: nil,
          bot_user: bot_user,
        )

      result = runner.invoke
      expect(result["success"]).to eq(true)
      expect(result["persona"]["system_prompt"]).to eq("Updated system prompt")
      expect(result["persona"]["temperature"]).to eq(0.7)

      ai_persona.reload
      expect(ai_persona.system_prompt).to eq("Updated system prompt")
      expect(ai_persona.temperature).to eq(0.7)
      expect(ai_persona.top_p).to eq(0.9)
    end
  end

  context "when fetching persona information" do
    fab!(:ai_persona) do
      Fabricate(
        :ai_persona,
        name: "TestPersona",
        description: "Test description",
        system_prompt: "Test system prompt",
        temperature: 0.8,
        top_p: 0.9,
        vision_enabled: true,
        tools: ["Search", ["WebSearch", { param: "value" }, true]],
      )
    end

    it "can fetch a persona by name" do
      script = <<~JS
        function invoke(params) {
          const persona = discourse.getPersona(params.persona_name);
          return persona;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ persona_name: "TestPersona" }, llm: nil, bot_user: bot_user)

      result = runner.invoke

      expect(result["id"]).to eq(ai_persona.id)
      expect(result["name"]).to eq("TestPersona")
      expect(result["description"]).to eq("Test description")
      expect(result["system_prompt"]).to eq("Test system prompt")
      expect(result["temperature"]).to eq(0.8)
      expect(result["top_p"]).to eq(0.9)
      expect(result["vision_enabled"]).to eq(true)
      expect(result["tools"]).to include("Search")
      expect(result["tools"][1]).to be_a(Array)
    end

    it "raises an error when the persona doesn't exist" do
      script = <<~JS
        function invoke(params) {
          return discourse.getPersona("NonExistentPersona");
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: bot_user)

      expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Persona not found/)
    end

    it "can update a persona after fetching it" do
      script = <<~JS
        function invoke(params) {
          const persona = discourse.getPersona("TestPersona");
          return persona.update({
            system_prompt: "Updated through getPersona().update()",
            temperature: 0.5
          });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: bot_user)

      result = runner.invoke
      expect(result["success"]).to eq(true)

      ai_persona.reload
      expect(ai_persona.system_prompt).to eq("Updated through getPersona().update()")
      expect(ai_persona.temperature).to eq(0.5)
    end
  end

  it "can use sleep function with limits" do
    script = <<~JS
      function invoke(params) {
        let results = [];
        for (let i = 0; i < 3; i++) {
          let result = sleep(1); // 1ms sleep
          results.push(result);
        }
        return results;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    result = runner.invoke

    expect(result).to eq([{ "slept" => 1 }, { "slept" => 1 }, { "slept" => 1 }])
  end

  let(:jpg) { plugin_file_from_fixtures("1x1.jpg") }

  describe "upload base64 encoding" do
    it "can get base64 data from upload ID and short URL" do
      upload = UploadCreator.new(jpg, "1x1.jpg").create_for(Discourse.system_user.id)

      # Test with upload ID
      script_id = <<~JS
        function invoke(params) {
          return upload.getBase64(params.upload_id, params.max_pixels);
        }
      JS

      tool = create_tool(script: script_id)
      runner =
        tool.runner(
          { "upload_id" => upload.id, "max_pixels" => 1_000_000 },
          llm: nil,
          bot_user: nil,
        )
      result_id = runner.invoke

      expect(result_id).to be_present
      expect(result_id).to be_a(String)
      expect(result_id.length).to be > 0

      # Test with short URL
      script_url = <<~JS
        function invoke(params) {
          return upload.getBase64(params.short_url, params.max_pixels);
        }
      JS

      tool = create_tool(script: script_url)
      runner =
        tool.runner(
          { "short_url" => upload.short_url, "max_pixels" => 1_000_000 },
          llm: nil,
          bot_user: nil,
        )
      result_url = runner.invoke

      expect(result_url).to be_present
      expect(result_url).to be_a(String)
      expect(result_url).to eq(result_id) # Should return same base64 data

      # Test with invalid upload ID
      script_invalid = <<~JS
        function invoke(params) {
          return upload.getBase64(99999);
        }
      JS

      tool = create_tool(script: script_invalid)
      runner = tool.runner({}, llm: nil, bot_user: nil)
      result_invalid = runner.invoke

      expect(result_invalid).to be_nil
    end
  end

  describe "upload URL resolution" do
    it "can resolve upload short URLs to public URLs" do
      upload =
        Fabricate(
          :upload,
          sha1: "abcdef1234567890abcdef1234567890abcdef12",
          url: "/uploads/default/original/1X/test.jpg",
          original_filename: "test.jpg",
        )

      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "short_url" => upload.short_url }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result).to eq(GlobalPath.full_cdn_url(upload.url))
    end

    it "returns null for invalid upload short URLs" do
      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner = tool.runner({ "short_url" => "upload://invalid" }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result).to be_nil
    end

    it "returns null for non-existent uploads" do
      script = <<~JS
      function invoke(params) {
        return upload.getUrl(params.short_url);
      }
    JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { "short_url" => "upload://hwmUkTAL9mwhQuRMLsXw6tvDi5C.jpeg" },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result).to be_nil
    end
  end

  context "when creating staged users" do
    it "can create a staged user" do
      script = <<~JS
        function invoke(params) {
          return discourse.createStagedUser({
            email: params.email,
            username: params.username,
            name: params.name
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { email: "testuser@example.com", username: "testuser123", name: "Test User" },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true)
      expect(result["username"]).to eq("testuser123")
      expect(result["email"]).to eq("testuser@example.com")

      user = User.find_by(id: result["user_id"])
      expect(user).not_to be_nil
      expect(user.staged).to eq(true)
      expect(user.username).to eq("testuser123")
      expect(user.email).to eq("testuser@example.com")
      expect(user.name).to eq("Test User")
    end

    it "returns an error if user already exists" do
      existing_user = Fabricate(:user, email: "existing@example.com", username: "existinguser")

      script = <<~JS
        function invoke(params) {
          try {
          return discourse.createStagedUser({
            email: params.email,
            username: params.username
          });
          } catch (e) {
            return { error: e.message };
          }
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { email: existing_user.email, username: "newusername" },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["error"]).to eq("User already exists")
    end
  end

  context "when creating topics" do
    fab!(:category)
    fab!(:user) { Fabricate(:admin) }

    it "can create a topic" do
      script = <<~JS
        function invoke(params) {
          return discourse.createTopic({
            category_id: params.category_id,
            title: params.title,
            raw: params.raw,
            username: params.username,
            tags: params.tags
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          {
            category_id: category.id,
            title: "Test Topic Title",
            raw: "This is the content of the test topic",
            username: user.username,
            tags: %w[test example],
          },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true)
      expect(result["topic_id"]).to be_present
      expect(result["post_id"]).to be_present

      topic = Topic.find_by(id: result["topic_id"])
      expect(topic).not_to be_nil
      expect(topic.title).to eq("Test Topic Title")
      expect(topic.category_id).to eq(category.id)
      expect(topic.user_id).to eq(user.id)
      expect(topic.archetype).to eq("regular")
      expect(topic.tags.pluck(:name)).to contain_exactly("test", "example")

      post = Post.find_by(id: result["post_id"])
      expect(post).not_to be_nil
      expect(post.raw).to eq("This is the content of the test topic")
    end

    it "can create a topic without username (uses system user)" do
      script = <<~JS
        function invoke(params) {
          return discourse.createTopic({
            category_id: params.category_id,
            title: params.title,
            raw: params.raw
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { category_id: category.id, title: "System User Topic", raw: "Created by system" },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true)

      topic = Topic.find_by(id: result["topic_id"])
      expect(topic.user_id).to eq(Discourse.system_user.id)
    end

    it "returns an error for invalid category" do
      script = <<~JS
        function invoke(params) {
          return discourse.createTopic({
            category_id: 99999,
            title: "Test",
            raw: "Test"
          });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: nil)

      expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Category not found/)
    end
  end

  context "when creating posts" do
    fab!(:topic) { Fabricate(:post).topic }
    fab!(:user)

    it "can create a post in a topic" do
      script = <<~JS
        function invoke(params) {
          return discourse.createPost({
            topic_id: params.topic_id,
            raw: params.raw,
            username: params.username
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { topic_id: topic.id, raw: "This is a reply to the topic", username: user.username },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true)
      expect(result["post_id"]).to be_present
      expect(result["post_number"]).to be > 1

      post = Post.find_by(id: result["post_id"])
      expect(post).not_to be_nil
      expect(post.raw).to eq("This is a reply to the topic")
      expect(post.topic_id).to eq(topic.id)
      expect(post.user_id).to eq(user.id)
    end

    it "can create a reply to a specific post" do
      _original_post = Fabricate(:post, topic: topic, post_number: 2)

      script = <<~JS
        function invoke(params) {
          return discourse.createPost({
            topic_id: params.topic_id,
            raw: params.raw,
            reply_to_post_number: params.reply_to_post_number
          });
        }
      JS

      tool = create_tool(script: script)
      runner =
        tool.runner(
          { topic_id: topic.id, raw: "This is a reply to post #2", reply_to_post_number: 2 },
          llm: nil,
          bot_user: nil,
        )

      result = runner.invoke

      expect(result["success"]).to eq(true)

      post = Post.find_by(id: result["post_id"])
      expect(post.reply_to_post_number).to eq(2)
    end

    it "returns an error for invalid topic" do
      script = <<~JS
        function invoke(params) {
          return discourse.createPost({
            topic_id: 99999,
            raw: "Test"
          });
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: nil)

      expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Topic not found/)
    end
  end

  context "when seeding a category with topics" do
    fab!(:category)

    it "can seed a category with a topic and post" do
      script = <<~JS
        function invoke(params) {
          // Create a staged user
          const user = discourse.createStagedUser({
            email: 'testuser@example.com',
            username: 'testuser',
            name: 'Test User'
          });

          // Create a topic
          const topic = discourse.createTopic({
            category_name: params.category_name,
            title: 'Test Topic 123 123 123',
            raw: 'This is the initial post content.',
            username: user.username
          });

          // Add an extra post to the topic
          const post = discourse.createPost({
            topic_id: topic.topic_id,
            raw: 'This is a reply to the topic.',
            username: user.username
          });

          return {
            success: true,
            user: user,
            topic: topic,
            post: post
          };
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ category_name: category.name }, llm: nil, bot_user: nil)

      result = runner.invoke

      expect(result["success"]).to eq(true)

      user = User.find_by(username: "testuser")
      expect(user).not_to be_nil
      expect(user.staged).to eq(true)

      topic = Topic.find_by(id: result["topic"]["topic_id"])
      expect(topic).not_to be_nil
      expect(topic.category_id).to eq(category.id)

      expect(topic.posts.count).to eq(2)
    end
  end
end
