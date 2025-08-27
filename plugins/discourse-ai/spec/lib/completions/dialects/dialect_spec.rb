# frozen_string_literal: true

class TestDialect < DiscourseAi::Completions::Dialects::Dialect
  attr_accessor :max_prompt_tokens

  def trim(messages)
    trim_messages(messages)
  end

  def system_msg(msg)
    msg
  end

  def user_msg(msg)
    msg
  end

  def model_msg(msg)
    msg
  end

  def tokenizer
    DiscourseAi::Tokenizer::OpenAiTokenizer
  end
end

RSpec.describe DiscourseAi::Completions::Dialects::Dialect do
  fab!(:llm_model)

  before { enable_current_plugin }

  describe "#translate" do
    let(:five_token_msg) { "This represents five tokens." }
    let(:tools) do
      [
        {
          name: "echo",
          description: "echo a string",
          parameters: [
            { name: "text", type: "string", description: "string to echo", required: true },
          ],
        },
      ]
    end

    it "injects done message when tool_choice is :none and last message follows tool pattern" do
      tool_call_prompt = { name: "echo", arguments: { text: "test message" } }

      prompt = DiscourseAi::Completions::Prompt.new("System instructions", tools: tools)
      prompt.push(type: :user, content: "echo test message")
      prompt.push(type: :tool_call, content: tool_call_prompt.to_json, id: "123", name: "echo")
      prompt.push(type: :tool, content: "test message".to_json, name: "echo", id: "123")
      prompt.tool_choice = :none

      dialect = TestDialect.new(prompt, llm_model)
      dialect.max_prompt_tokens = 100 # Set high enough to avoid trimming

      translated = dialect.translate

      expect(translated).to eq(
        [
          { type: :system, content: "System instructions" },
          { type: :user, content: "echo test message" },
          {
            type: :tool_call,
            content:
              "<function_calls>\n<invoke>\n<tool_name>echo</tool_name>\n<parameters>\n<text>test message</text>\n</parameters>\n</invoke>\n</function_calls>",
            id: "123",
            name: "echo",
          },
          {
            type: :tool,
            id: "123",
            name: "echo",
            content:
              "<function_results>\n<result>\n<tool_name>echo</tool_name>\n<json>\n\"test message\"\n</json>\n</result>\n</function_results>\n\n#{::DiscourseAi::Completions::Dialects::XmlTools::DONE_MESSAGE}",
          },
        ],
      )
    end
  end

  describe "#trim_messages" do
    let(:five_token_msg) { "This represents five tokens." }

    it "should trim tool messages if tool_calls are trimmed" do
      prompt = DiscourseAi::Completions::Prompt.new(five_token_msg)
      prompt.push(type: :user, content: five_token_msg)
      prompt.push(type: :tool_call, content: five_token_msg, id: 1)
      prompt.push(type: :tool, content: five_token_msg, id: 1)
      prompt.push(type: :user, content: five_token_msg)

      dialect = TestDialect.new(prompt, llm_model)
      dialect.max_prompt_tokens = 15 # fits the user messages and the tool_call message

      trimmed = dialect.trim(prompt.messages)

      expect(trimmed).to eq(
        [{ type: :system, content: five_token_msg }, { type: :user, content: five_token_msg }],
      )
    end

    it "limits the system message to 60% of available tokens" do
      prompt =
        DiscourseAi::Completions::Prompt.new("I'm a system message consisting of 10 tokens okay")
      prompt.push(type: :user, content: five_token_msg)

      dialect = TestDialect.new(prompt, llm_model)
      dialect.max_prompt_tokens = 15

      trimmed = dialect.trim(prompt.messages)

      expect(trimmed).to eq(
        [
          { type: :system, content: "I'm a system message consisting of 10 tokens" },
          { type: :user, content: five_token_msg },
        ],
      )
    end
  end
end
