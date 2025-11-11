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
    expect(final_result.signature).to eq("thinking-sig-123")
    expect(final_result.partial?).to eq(false)
  end
end
