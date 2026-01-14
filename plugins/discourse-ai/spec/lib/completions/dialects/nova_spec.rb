# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Nova do
  fab!(:llm_model) { Fabricate(:nova_model, vision_enabled: true) }

  let(:nova_dialect_klass) { DiscourseAi::Completions::Dialects::Dialect.dialect_for(llm_model) }

  before { enable_current_plugin }

  it "finds the right dialect" do
    expect(nova_dialect_klass).to eq(DiscourseAi::Completions::Dialects::Nova)
  end

  describe "#translate" do
    it "properly formats a basic conversation" do
      messages = [
        { type: :user, id: "user1", content: "Hello" },
        { type: :model, content: "Hi there!" },
      ]

      prompt = DiscourseAi::Completions::Prompt.new("You are a helpful bot", messages: messages)
      dialect = nova_dialect_klass.new(prompt, llm_model)
      translated = dialect.translate

      expect(translated.system).to eq([{ text: "You are a helpful bot" }])
      expect(translated.messages).to eq(
        [
          { role: "user", content: [{ text: "Hello" }] },
          { role: "assistant", content: [{ text: "Hi there!" }] },
        ],
      )
    end

    context "with image content" do
      let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
      let(:upload) do
        UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
      end

      it "properly formats messages with images" do
        messages = [
          {
            type: :user,
            id: "user1",
            content: ["What's in this image?", { upload_id: upload.id }],
          },
        ]

        prompt = DiscourseAi::Completions::Prompt.new(messages: messages)

        dialect = nova_dialect_klass.new(prompt, llm_model)
        translated = dialect.translate

        encoded = prompt.encoded_uploads(messages.first).first[:base64]

        expect(translated.messages.first[:content]).to eq(
          [
            { text: "What's in this image?" },
            { image: { format: "jpeg", source: { bytes: encoded } } },
          ],
        )
      end
    end

    context "with tools" do
      it "properly formats tool configuration" do
        tools = [
          {
            name: "get_weather",
            description: "Get the weather in a city",
            parameters: [
              { name: "location", type: "string", description: "the city name", required: true },
            ],
          },
        ]

        messages = [{ type: :user, content: "What's the weather?" }]

        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a helpful bot",
            messages: messages,
            tools: tools,
          )

        dialect = nova_dialect_klass.new(prompt, llm_model)
        translated = dialect.translate

        expected = {
          tools: [
            {
              toolSpec: {
                name: "get_weather",
                description: "Get the weather in a city",
                inputSchema: {
                  json: {
                    type: "object",
                    properties: {
                      "location" => {
                        type: :string,
                        description: "the city name",
                      },
                    },
                    required: ["location"],
                  },
                },
              },
            },
          ],
        }

        expect(translated.tool_config).to eq(expected)
      end
    end

    context "with inference configuration" do
      it "includes inference configuration when provided" do
        messages = [{ type: :user, content: "Hello" }]

        prompt = DiscourseAi::Completions::Prompt.new("You are a helpful bot", messages: messages)

        dialect = nova_dialect_klass.new(prompt, llm_model)

        options = { temperature: 0.7, top_p: 0.9, max_tokens: 100, stop_sequences: ["STOP"] }

        translated = dialect.translate

        expected = {
          system: [{ text: "You are a helpful bot" }],
          messages: [{ role: "user", content: [{ text: "Hello" }] }],
          inferenceConfig: {
            temperature: 0.7,
            top_p: 0.9,
            stopSequences: ["STOP"],
            max_new_tokens: 100,
          },
        }

        expect(translated.to_payload(options)).to eq(expected)
      end

      it "omits inference configuration when not provided" do
        messages = [{ type: :user, content: "Hello" }]

        prompt = DiscourseAi::Completions::Prompt.new("You are a helpful bot", messages: messages)

        dialect = nova_dialect_klass.new(prompt, llm_model)
        translated = dialect.translate

        expect(translated.inference_config).to be_nil
      end
    end

    it "handles tool calls and responses" do
      tool_call_prompt = { name: "get_weather", arguments: { location: "London" } }

      messages = [
        { type: :user, id: "user1", content: "What's the weather in London?" },
        { type: :tool_call, name: "get_weather", id: "tool_id", content: tool_call_prompt.to_json },
        { type: :tool, id: "tool_id", content: "Sunny, 22°C".to_json },
        { type: :model, content: "The weather in London is sunny with 22°C" },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a helpful bot",
          messages: messages,
          tools: [
            {
              name: "get_weather",
              description: "Get the weather in a city",
              parameters: [
                { name: "location", type: "string", description: "the city name", required: true },
              ],
            },
          ],
        )

      dialect = nova_dialect_klass.new(prompt, llm_model)
      translated = dialect.translate

      expect(translated.messages.map { |m| m[:role] }).to eq(%w[user assistant user assistant])
      expect(translated.messages.last[:content]).to eq(
        [{ text: "The weather in London is sunny with 22°C" }],
      )
    end
  end

  describe "#max_prompt_tokens" do
    it "returns the model's max prompt tokens" do
      prompt = DiscourseAi::Completions::Prompt.new("You are a helpful bot")
      dialect = nova_dialect_klass.new(prompt, llm_model)

      expect(dialect.max_prompt_tokens).to eq(llm_model.max_prompt_tokens)
    end
  end
end
