# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Gemini do
  fab!(:model) { Fabricate(:gemini_model) }
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
