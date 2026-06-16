# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::NativeTools do
  before { enable_current_plugin }

  fab!(:gemini_model)
  fab!(:anthropic_model)
  fab!(:openai_chat_model) do
    Fabricate(:llm_model, url: "https://api.openai.com/v1/chat/completions")
  end
  fab!(:openai_responses_model) do
    Fabricate(:llm_model, url: "https://api.openai.com/v1/responses")
  end
  fab!(:bedrock_model)

  describe ".supported_ids_for" do
    it "supports Gemini grounding and URL context" do
      expect(described_class.supported_ids_for(gemini_model)).to eq(%w[web_search web_fetch])
    end

    it "supports Anthropic web search and fetch" do
      expect(described_class.supported_ids_for(anthropic_model)).to eq(%w[web_search web_fetch])
    end

    it "supports OpenAI web search only on the Responses API" do
      expect(described_class.supported_ids_for(openai_responses_model)).to eq(["web_search"])
      expect(described_class.supported_ids_for(openai_chat_model)).to eq([])
    end

    it "does not support Bedrock" do
      expect(described_class.supported_ids_for(bedrock_model)).to eq([])
    end

    it "returns [] for a nil model" do
      expect(described_class.supported_ids_for(nil)).to eq([])
    end
  end

  describe ".valid? and prefixing" do
    it "validates ids regardless of prefix" do
      expect(described_class.valid?("web_search")).to eq(true)
      expect(described_class.valid?("native-web_search")).to eq(true)
      expect(described_class.valid?("web_fetch")).to eq(true)
      expect(described_class.valid?("native-web_fetch")).to eq(true)
      expect(described_class.valid?("nope")).to eq(false)
    end

    it "detects and strips the prefix" do
      expect(described_class.prefixed?("native-web_search")).to eq(true)
      expect(described_class.prefixed?("web_search")).to eq(false)
      expect(described_class.strip_prefix("native-web_search")).to eq("web_search")
    end
  end

  describe "dialect rendering" do
    let(:web_search_prompt) do
      prompt =
        DiscourseAi::Completions::Prompt.new("system", messages: [{ type: :user, content: "hi" }])
      prompt.native_tools = ["web_search"]
      prompt
    end

    it "renders Gemini native web tools" do
      prompt =
        DiscourseAi::Completions::Prompt.new("system", messages: [{ type: :user, content: "hi" }])
      prompt.native_tools = %w[web_search web_fetch]

      dialect = DiscourseAi::Completions::Dialects::Gemini.new(prompt, gemini_model)
      expect(dialect.tools).to eq([{ google_search: {} }, { url_context: {} }])
    end

    it "renders google_search alongside function declarations for Gemini" do
      web_search_prompt.tools = [
        {
          name: "echo",
          description: "echo",
          parameters: [{ name: "text", description: "text to echo", type: "string" }],
        },
      ]

      dialect = DiscourseAi::Completions::Dialects::Gemini.new(web_search_prompt, gemini_model)
      tools = dialect.tools

      expect(tools.find { |t| t.key?(:function_declarations) }).to be_present
      expect(tools).to include({ google_search: {} })
    end

    it "renders the web search and fetch tools for Claude" do
      web_search_prompt.native_tools = %w[web_search web_fetch]
      dialect = DiscourseAi::Completions::Dialects::Claude.new(web_search_prompt, anthropic_model)
      translated = dialect.translate

      expect(translated.tools).to include({ type: "web_search_20250305", name: "web_search" })
      expect(translated.tools).to include(
        { type: "web_fetch_20260209", name: "web_fetch", allowed_callers: %w[direct] },
      )
    end

    it "renders the web search tool for the OpenAI Responses API" do
      dialect =
        DiscourseAi::Completions::Dialects::OpenAiResponses.new(
          web_search_prompt,
          openai_responses_model,
        )

      expect(dialect.native_tools).to eq([{ type: "web_search" }])
    end

    it "does not render OpenAI web fetch" do
      prompt =
        DiscourseAi::Completions::Prompt.new("system", messages: [{ type: :user, content: "hi" }])
      prompt.native_tools = ["web_fetch"]
      dialect =
        DiscourseAi::Completions::Dialects::OpenAiResponses.new(prompt, openai_responses_model)

      expect(dialect.native_tools).to eq([])
    end

    it "does not duplicate the OpenAI native web tool when unknown fetch is also present" do
      prompt =
        DiscourseAi::Completions::Prompt.new("system", messages: [{ type: :user, content: "hi" }])
      prompt.native_tools = %w[web_search web_fetch]
      dialect =
        DiscourseAi::Completions::Dialects::OpenAiResponses.new(prompt, openai_responses_model)

      expect(dialect.native_tools).to eq([{ type: "web_search" }])
    end

    it "renders nothing when no native tools are enabled" do
      prompt =
        DiscourseAi::Completions::Prompt.new("system", messages: [{ type: :user, content: "hi" }])

      gemini = DiscourseAi::Completions::Dialects::Gemini.new(prompt, gemini_model)
      claude = DiscourseAi::Completions::Dialects::Claude.new(prompt, anthropic_model)

      expect(gemini.tools).to be_nil
      expect(claude.translate.tools).to be_blank
    end
  end

  describe "response handling (enable-only)" do
    it "ignores Anthropic server-side web search blocks and keeps the text" do
      processor = DiscourseAi::Completions::AnthropicMessageProcessor.new(streaming_mode: false)

      payload = {
        content: [
          { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: { query: "x" } },
          {
            type: "web_search_tool_result",
            tool_use_id: "srvtoolu_1",
            content: [{ type: "web_search_result", url: "https://example.com", title: "Example" }],
          },
          { type: "text", text: "Based on my search, the answer is 42." },
        ],
        usage: {
          input_tokens: 10,
          output_tokens: 5,
        },
      }

      result = processor.process_message(payload)

      expect(result).to eq(["Based on my search, the answer is 42."])
      expect(result.any? { |r| r.is_a?(DiscourseAi::Completions::ToolCall) }).to eq(false)
    end
  end
end
