# frozen_string_literal: true

describe DiscourseAi::Completions::AnthropicMessageProcessor do
  before { enable_current_plugin }

  it "correctly handles and combines partial thinking chunks into complete thinking objects" do
    processor =
      DiscourseAi::Completions::AnthropicMessageProcessor.new(
        streaming_mode: true,
        partial_tool_calls: false,
        output_thinking: true,
      )

    # Simulate streaming thinking output in multiple chunks
    result1 =
      processor.process_streamed_message(
        { type: "content_block_start", content_block: { type: "thinking", thinking: "" } },
      )

    result2 =
      processor.process_streamed_message(
        {
          type: "content_block_delta",
          delta: {
            type: "thinking_delta",
            thinking: "First part of thinking",
          },
        },
      )

    result3 =
      processor.process_streamed_message(
        {
          type: "content_block_delta",
          delta: {
            type: "thinking_delta",
            thinking: " and second part",
          },
        },
      )

    _result4 =
      processor.process_streamed_message(
        {
          type: "content_block_delta",
          delta: {
            type: "signature_delta",
            signature: "thinking-sig-123",
          },
        },
      )

    # Finish the thinking block
    final_result = processor.process_streamed_message({ type: "content_block_stop" })

    # Verify the partial thinking chunks
    expect(result1).to be_a(DiscourseAi::Completions::Thinking)
    expect(result1.message).to eq("")
    expect(result1.partial?).to eq(true)

    expect(result2).to be_a(DiscourseAi::Completions::Thinking)
    expect(result2.message).to eq("First part of thinking")
    expect(result2.partial?).to eq(true)

    expect(result3).to be_a(DiscourseAi::Completions::Thinking)
    expect(result3.message).to eq(" and second part")
    expect(result3.partial?).to eq(true)

    # Verify the final complete thinking object
    expect(final_result).to be_a(DiscourseAi::Completions::Thinking)
    expect(final_result.message).to eq("First part of thinking and second part")
    expect(final_result.provider_info[:anthropic][:signature]).to eq("thinking-sig-123")
    expect(final_result.partial?).to eq(false)
  end

  it "emits thinking for streamed server-side web search" do
    processor =
      DiscourseAi::Completions::AnthropicMessageProcessor.new(
        streaming_mode: true,
        partial_tool_calls: false,
        output_thinking: true,
      )

    processor.process_streamed_message(
      {
        type: "content_block_start",
        content_block: {
          type: "server_tool_use",
          id: "srvtoolu_1",
          name: "web_search",
          input: {
          },
        },
      },
    )
    processor.process_streamed_message(
      {
        type: "content_block_delta",
        delta: {
          type: "input_json_delta",
          partial_json: '{"query":"HackerOne AI news today"}',
        },
      },
    )

    result = processor.process_streamed_message({ type: "content_block_stop" })

    expect(result).to be_a(DiscourseAi::Completions::Thinking)
    expect(result.message).to eq("Web search: HackerOne AI news today")
    expect(result.provider_info).to eq({})
    expect(result).not_to be_partial

    processor.process_streamed_message(
      {
        type: "content_block_start",
        content_block: {
          type: "web_search_tool_result",
          tool_use_id: "srvtoolu_1",
          content: [
            {
              type: "web_search_result",
              title: "Example",
              url: "https://example.com",
              encrypted_content: "encrypted",
            },
          ],
        },
      },
    )
    processor.process_streamed_message({ type: "content_block_stop" })
    processor.process_streamed_message(
      { type: "content_block_start", content_block: { type: "text", text: "" } },
    )
    citation = {
      type: "web_search_result_location",
      url: "https://example.com",
      title: "Example",
      encrypted_index: "encrypted-index",
      cited_text: "Example cited text",
    }
    processor.process_streamed_message(
      { type: "content_block_delta", delta: { type: "citations_delta", citation: citation } },
    )
    processor.process_streamed_message(
      { type: "content_block_delta", delta: { type: "text_delta", text: "Answer" } },
    )
    processor.process_streamed_message({ type: "content_block_stop" })

    provider_result = processor.process_streamed_message({ type: "message_stop" })
    content_blocks = provider_result.provider_info.dig(:anthropic, :content_blocks)

    expect(provider_result).to be_a(DiscourseAi::Completions::Thinking)
    expect(provider_result.message).to be_nil
    expect(content_blocks).to include(
      {
        type: "server_tool_use",
        id: "srvtoolu_1",
        name: "web_search",
        input: {
          query: "HackerOne AI news today",
        },
      },
    )
    expect(content_blocks).to include(
      {
        type: "web_search_tool_result",
        tool_use_id: "srvtoolu_1",
        content: [
          {
            type: "web_search_result",
            title: "Example",
            url: "https://example.com",
            encrypted_content: "encrypted",
          },
        ],
      },
      { type: "text", text: "Answer", citations: [citation] },
    )
  end

  it "preserves streamed thinking with server tools" do
    processor =
      DiscourseAi::Completions::AnthropicMessageProcessor.new(
        streaming_mode: true,
        partial_tool_calls: false,
        output_thinking: true,
      )

    processor.process_streamed_message(
      { type: "content_block_start", content_block: { type: "thinking", thinking: "" } },
    )
    processor.process_streamed_message(
      { type: "content_block_delta", delta: { type: "thinking_delta", thinking: "Need search" } },
    )
    processor.process_streamed_message(
      { type: "content_block_delta", delta: { type: "signature_delta", signature: "sig-123" } },
    )
    processor.process_streamed_message({ type: "content_block_stop" })
    processor.process_streamed_message(
      {
        type: "content_block_start",
        content_block: {
          type: "server_tool_use",
          id: "srvtoolu_1",
          name: "web_search",
          input: {
          },
        },
      },
    )
    processor.process_streamed_message(
      {
        type: "content_block_delta",
        delta: {
          type: "input_json_delta",
          partial_json: '{"query":"Discourse AI"}',
        },
      },
    )
    processor.process_streamed_message({ type: "content_block_stop" })

    provider_result = processor.process_streamed_message({ type: "message_stop" })

    expect(provider_result.provider_info.dig(:anthropic, :content_blocks)).to start_with(
      { type: "thinking", thinking: "Need search", signature: "sig-123" },
    )
  end

  it "emits thinking for non-streamed server-side web search" do
    processor =
      DiscourseAi::Completions::AnthropicMessageProcessor.new(
        streaming_mode: false,
        output_thinking: true,
      )

    payload = {
      content: [
        { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: { query: "x" } },
        { type: "text", text: "Based on my search, the answer is 42." },
      ],
      usage: {
        input_tokens: 10,
        output_tokens: 5,
      },
    }

    result = processor.process_message(payload)

    expect(result.first).to be_a(DiscourseAi::Completions::Thinking)
    expect(result.first.message).to eq("Web search: x")
    expect(result.first.provider_info.dig(:anthropic, :content_blocks)).to include(
      { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: { query: "x" } },
    )
    expect(result.last).to eq("Based on my search, the answer is 42.")
  end
end
