# frozen_string_literal: true

describe DiscourseAi::Completions do
  it "distinguishes Responses API output exhaustion from a completed answer" do
    processor = DiscourseAi::Completions::OpenAiResponsesMessageProcessor.new
    processor.process_message(
      status: "incomplete",
      incomplete_details: {
        reason: "max_output_tokens",
      },
      output: [],
    )
    expect(processor.stop_reason).to eq("max_output_tokens")

    processor = DiscourseAi::Completions::OpenAiResponsesMessageProcessor.new
    processor.process_streamed_message(
      type: "response.incomplete",
      response: {
        incomplete_details: {
          reason: "max_output_tokens",
        },
      },
    )
    expect(processor.stop_reason).to eq("max_output_tokens")

    processor = DiscourseAi::Completions::OpenAiResponsesMessageProcessor.new
    processor.process_streamed_message(type: "response.completed", response: { output: [] })
    expect(processor.stop_reason).to be_nil
  end

  it "retains the chat completion length stop reason" do
    processor = DiscourseAi::Completions::OpenAiMessageProcessor.new
    processor.process_streamed_message(
      choices: [{ delta: { content: "Partial" }, finish_reason: "length" }],
    )
    expect(processor.stop_reason).to eq("length")
  end

  it "retains the Anthropic output limit for streamed and complete responses" do
    processor = DiscourseAi::Completions::AnthropicMessageProcessor.new(streaming_mode: true)
    processor.process_streamed_message(
      type: "message_delta",
      delta: {
        stop_reason: "max_tokens",
      },
      usage: {
        output_tokens: 16,
      },
    )
    expect(processor.stop_reason).to eq("max_tokens")
    processor = DiscourseAi::Completions::AnthropicMessageProcessor.new(streaming_mode: false)
    processor.process_message(content: [], stop_reason: "max_tokens")
    expect(processor.stop_reason).to eq("max_tokens")
  end

  context "with truncated streamed tool arguments" do
    {
      DiscourseAi::Completions::AnthropicMessageProcessor => [
        {
          type: "content_block_start",
          content_block: {
            type: "tool_use",
            id: "read",
            name: "search",
            input: {
            },
          },
        },
        {
          type: "content_block_delta",
          delta: {
            type: "input_json_delta",
            partial_json: '{"query":"unfinished',
          },
        },
        { type: "content_block_stop" },
        { type: "message_delta", delta: { stop_reason: "STOP" }, usage: { output_tokens: 16 } },
      ],
      DiscourseAi::Completions::ConverseMessageProcessor => [
        {
          type: :content_block_start,
          start: {
            tool_use: {
              tool_use_id: "read",
              name: "search",
            },
          },
        },
        { type: :content_block_delta, delta: { tool_use: { input: '{"query":"unfinished' } } },
        { type: :content_block_stop },
        { type: :message_stop, stop_reason: "STOP" },
      ],
      DiscourseAi::Completions::NovaMessageProcessor => [
        { contentBlockStart: { start: { toolUse: { toolUseId: "read", name: "search" } } } },
        { contentBlockDelta: { delta: { toolUse: { input: '{"query":"unfinished' } } } },
        { contentBlockStop: {} },
        { messageStop: { stopReason: "STOP" } },
      ],
    }.each do |processor_class, events|
      context "with #{processor_class.name.demodulize}" do
        ["max_tokens", "end_turn", nil].each do |stop|
          it "#{stop == "max_tokens" ? "discards" : "rejects"} incomplete arguments when the stop reason is #{stop.inspect}" do
            processor = processor_class.new(streaming_mode: true)
            events.first(3).each { |event| processor.process_streamed_message(event) }
            if stop
              event = JSON.parse(events.last.to_json.gsub("STOP", stop), symbolize_names: true)
              event[:type] = event[:type].to_sym if processor_class ==
                DiscourseAi::Completions::ConverseMessageProcessor
              processor.process_streamed_message(event)
            end
            if stop == "max_tokens"
              expect(processor.finish).to eq([])
              expect(processor.stop_reason).to eq(stop)
            else
              expect { processor.finish }.to raise_error(JSON::ParserError)
            end
          end
        end
      end
    end
  end
end
