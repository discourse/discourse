# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Vllm do
  fab!(:model, :vllm_model)
  fab!(:open_ai_model, :llm_model)

  before { enable_current_plugin }

  it "is selected only for vLLM models" do
    expect(DiscourseAi::Completions::Dialects::Dialect.dialect_for(model)).to eq(described_class)
    expect(DiscourseAi::Completions::Dialects::Dialect.dialect_for(open_ai_model)).to eq(
      DiscourseAi::Completions::Dialects::ChatGpt,
    )
  end

  it "replays tool-call reasoning without adding reasoning to normal assistant messages" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "System instructions",
        messages: [
          { type: :user, content: "First request" },
          {
            type: :tool_call,
            id: "old-tool",
            name: "echo",
            content: { arguments: { text: "old" } }.to_json,
            thinking: "Old tool reasoning",
          },
          { type: :tool, id: "old-tool", name: "echo", content: '"old"' },
          { type: :model, content: "First answer", thinking: "Old answer reasoning" },
          { type: :user, content: "Second request" },
          {
            type: :tool_call,
            id: "current-tool",
            name: "echo",
            content: { arguments: { text: "current" } }.to_json,
            thinking: "Current tool reasoning",
          },
          { type: :tool, id: "current-tool", name: "echo", content: '"current"' },
        ],
      )

    translated = described_class.new(prompt, model).translate
    assistant_tool_calls = translated.select { |message| message[:tool_calls].present? }
    historical_answer = translated.find { |message| message[:content] == "First answer" }

    expect(assistant_tool_calls).to eq(
      [
        {
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              type: "function",
              function: {
                arguments: '{"text":"old"}',
                name: "echo",
              },
              id: "old-tool",
            },
          ],
          reasoning_content: "Old tool reasoning",
        },
        {
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              type: "function",
              function: {
                arguments: '{"text":"current"}',
                name: "echo",
              },
              id: "current-tool",
            },
          ],
          reasoning_content: "Current tool reasoning",
        },
      ],
    )
    expect(historical_answer).to eq(role: "assistant", content: "First answer")
  end

  it "reconstructs parallel tool-call batches" do
    provider_data = { vllm: { tool_batch_id: "response-1" } }
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "System instructions",
        messages: [
          { type: :user, content: "Run both tools" },
          {
            type: :tool_call,
            id: "tool-1",
            name: "echo",
            content: { arguments: { text: "one" } }.to_json,
            thinking: "Call both tools",
            provider_data: provider_data,
          },
          {
            type: :tool,
            id: "tool-1",
            name: "echo",
            content: '"one"',
            provider_data: provider_data,
          },
          {
            type: :tool_call,
            id: "tool-2",
            name: "echo",
            content: { arguments: { text: "two" } }.to_json,
            provider_data: provider_data,
          },
          {
            type: :tool,
            id: "tool-2",
            name: "echo",
            content: '"two"',
            provider_data: provider_data,
          },
        ],
      )

    expect(described_class.new(prompt, model).translate).to eq(
      [
        { role: "system", content: "System instructions" },
        { role: "user", content: "Run both tools" },
        {
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              type: "function",
              function: {
                arguments: '{"text":"one"}',
                name: "echo",
              },
              id: "tool-1",
            },
            {
              type: "function",
              function: {
                arguments: '{"text":"two"}',
                name: "echo",
              },
              id: "tool-2",
            },
          ],
          reasoning_content: "Call both tools",
        },
        { role: "tool", tool_call_id: "tool-1", content: '"one"', name: "echo" },
        { role: "tool", tool_call_id: "tool-2", content: '"two"', name: "echo" },
      ],
    )
  end

  it "does not merge a reused batch ID across user turns" do
    provider_data = { vllm: { tool_batch_id: "reused-response-id" } }
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "System instructions",
        messages: [
          { type: :user, content: "First request" },
          {
            type: :tool_call,
            id: "tool-1",
            name: "echo",
            content: { arguments: { text: "one" } }.to_json,
            provider_data: provider_data,
          },
          {
            type: :tool,
            id: "tool-1",
            name: "echo",
            content: '"one"',
            provider_data: provider_data,
          },
          { type: :model, content: "First answer" },
          { type: :user, content: "Second request" },
          {
            type: :tool_call,
            id: "tool-2",
            name: "echo",
            content: { arguments: { text: "two" } }.to_json,
            provider_data: provider_data,
          },
          {
            type: :tool,
            id: "tool-2",
            name: "echo",
            content: '"two"',
            provider_data: provider_data,
          },
        ],
      )

    assistant_tool_messages =
      described_class.new(prompt, model).translate.select { |message| message[:tool_calls] }

    expect(
      assistant_tool_messages.map { |message| message[:tool_calls].map { |call| call[:id] } },
    ).to eq([%w[tool-1], %w[tool-2]])
  end

  it "keeps vLLM metadata out of XML tool messages" do
    model.update!(provider_params: { disable_native_tools: true })
    provider_data = { vllm: { tool_batch_id: "response-1" } }
    prompt =
      DiscourseAi::Completions::Prompt.new(
        "System instructions",
        messages: [
          { type: :user, content: "Run the tool" },
          {
            type: :tool_call,
            id: "tool-1",
            name: "echo",
            content: { arguments: { text: "one" } }.to_json,
            thinking: "Call the tool",
            provider_data: provider_data,
          },
          {
            type: :tool,
            id: "tool-1",
            name: "echo",
            content: '"one"',
            provider_data: provider_data,
          },
        ],
      )

    translated = described_class.new(prompt, model).translate

    expect(translated.flat_map(&:keys)).not_to include(:reasoning_content, :tool_batch_id)
  end
end
