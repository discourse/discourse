# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Gemini do
  fab!(:model, :gemini_model)
  let(:context) { DialectContext.new(described_class, model) }

  before { enable_current_plugin }

  describe "#translate" do
    it "translates a prompt written in our generic format to the Gemini format" do
      gemini_version = {
        messages: [{ role: "user", parts: [{ text: context.simple_user_input }] }],
        system_instruction: context.system_insts,
      }

      translated = context.system_user_scenario

      expect(translated).to eq(gemini_version)
    end

    describe "upload markdown stripping for image preview model" do
      fab!(:upload)
      let(:image_model) { Fabricate(:gemini_model, name: "gemini-2.5-flash-image-preview") }

      it "strips upload markdown from both user and model messages" do
        base62 = Upload.base62_sha1(upload.sha1)

        user_md = "User text start ![user image](upload://#{base62}.png) end."
        model_md = "Model text start ![model image](upload://#{base62}.png) end."

        prompt =
          DiscourseAi::Completions::Prompt.new(
            nil,
            messages: [
              { type: :system, content: "Sys" },
              { type: :user, content: [user_md, { upload_id: upload.id }] },
              { type: :model, content: [model_md, { upload_id: upload.id }] },
            ],
          )

        dialect = described_class.new(prompt, image_model)
        expect(dialect.strip_upload_markdown_mode).to eq(:all)

        translated = dialect.translate

        user_msg = translated[:messages].find { |m| m[:role] == "user" }
        model_msg = translated[:messages].find { |m| m[:role] == "model" }

        user_text = user_msg[:parts].map { |p| p[:text] }.join
        model_text = model_msg[:parts].map { |p| p[:text] }.join

        expect(user_text).to eq("User text start  end.")
        expect(model_text).to eq("Model text start  end.")
      end
    end

    it "injects model after tool call" do
      expect(context.image_generation_scenario).to eq(
        {
          messages: [
            { role: "user", parts: [{ text: "user1: draw a cat" }] },
            {
              role: "model",
              parts: [{ functionCall: { name: "draw", args: { picture: "Cat" } } }],
            },
            {
              role: "function",
              parts: [
                {
                  functionResponse: {
                    name: "tool_id",
                    response: {
                      content: "\"I'm a tool result\"",
                    },
                  },
                },
              ],
            },
            { role: "model", parts: { text: "Ok." } },
            { role: "user", parts: [{ text: "user1: draw another cat" }] },
          ],
          system_instruction: context.system_insts,
        },
      )
    end

    it "translates tool_call and tool messages" do
      expect(context.multi_turn_scenario).to eq(
        {
          messages: [
            { role: "user", parts: [{ text: "user1: This is a message by a user" }] },
            {
              role: "model",
              parts: [{ text: "I'm a previous bot reply, that's why there's no user" }],
            },
            { role: "user", parts: [{ text: "user1: This is a new message by a user" }] },
            {
              role: "model",
              parts: [
                { functionCall: { name: "get_weather", args: { location: "Sydney", unit: "c" } } },
              ],
            },
            {
              role: "function",
              parts: [
                {
                  functionResponse: {
                    name: "get_weather",
                    response: {
                      content: "\"I'm a tool result\"",
                    },
                  },
                },
              ],
            },
          ],
          system_instruction:
            "I want you to act as a title generator for written pieces. I will provide you with a text,\nand you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,\nand ensure that the meaning is maintained. Replies will utilize the language type of the topic.\n",
        },
      )
    end

    it "includes thoughtSignature for tool calls when provider data is present" do
      prompt = context.prompt
      prompt.push(type: :user, id: "user1", content: "call a tool")
      prompt.push(
        type: :tool_call,
        id: "tool_id",
        name: "get_weather",
        content: { arguments: { location: "Sydney" } }.to_json,
        provider_data: {
          thought_signature: "sig-123",
        },
      )
      prompt.push(type: :tool, id: "tool_id", name: "get_weather", content: { ok: true }.to_json)

      translated = context.dialect(prompt).translate

      tool_call_parts =
        translated[:messages].find { |message| message[:role] == "model" }.fetch(:parts).first

      expect(tool_call_parts[:thoughtSignature]).to eq("sig-123")
    end

    it "merges multiple tool calls from the same batch into a single model message" do
      prompt = context.prompt
      prompt.push(type: :user, id: "user1", content: "do two things")
      prompt.push(
        type: :tool_call,
        id: "tool_id_1",
        name: "get_weather",
        content: { arguments: { city: "Paris" } }.to_json,
        provider_data: {
          batch_id: "batch-1",
          thought_signature: "sig-A",
        },
      )
      prompt.push(
        type: :tool,
        id: "tool_id_1",
        name: "get_weather",
        content: { temp: "15C" }.to_json,
        provider_data: {
          batch_id: "batch-1",
        },
      )
      prompt.push(
        type: :tool_call,
        id: "tool_id_2",
        name: "get_weather",
        content: { arguments: { city: "London" } }.to_json,
        provider_data: {
          batch_id: "batch-1",
        },
      )
      prompt.push(
        type: :tool,
        id: "tool_id_2",
        name: "get_weather",
        content: { temp: "12C" }.to_json,
        provider_data: {
          batch_id: "batch-1",
        },
      )

      translated = context.dialect(prompt).translate

      model_message = translated[:messages].find { |m| m[:role] == "model" }
      function_message = translated[:messages].find { |m| m[:role] == "function" }

      expect(model_message[:parts].length).to eq(2)
      expect(model_message[:parts].first[:thoughtSignature]).to eq("sig-A")
      expect(model_message[:parts].second[:thoughtSignature]).to be_nil

      expect(function_message[:parts].length).to eq(2)
      expect(function_message[:parts].first.dig(:functionResponse, :response, :content)).to eq(
        { temp: "15C" }.to_json,
      )
      expect(function_message[:parts].second.dig(:functionResponse, :response, :content)).to eq(
        { temp: "12C" }.to_json,
      )
    end

    it "trims content if it's getting too long" do
      # testing truncation on 800k tokens is slow use model with less
      model.max_prompt_tokens = 16_384
      context = DialectContext.new(described_class, model)
      translated = context.long_user_input_scenario(length: 5_000)

      expect(translated[:messages].last[:role]).to eq("user")
      expect(translated[:messages].last.dig(:parts, 0, :text).length).to be <
        context.long_message_text(length: 5_000).length
    end
  end

  describe "#tools" do
    it "returns a list of available tools" do
      gemini_tools = {
        function_declarations: [
          {
            name: "get_weather",
            description: "Get the weather in a city",
            parameters: {
              type: "object",
              required: %w[location unit],
              properties: {
                "location" => {
                  type: :string,
                  description: "the city name",
                },
                "unit" => {
                  type: :string,
                  description: "the unit of measurement celcius c or fahrenheit f",
                  enum: %w[c f],
                },
              },
            },
          },
        ],
      }
      expect(context.dialect_tools).to contain_exactly(gemini_tools)
    end
  end
end
