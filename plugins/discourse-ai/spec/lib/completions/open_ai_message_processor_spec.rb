# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OpenAiMessageProcessor do
  before { enable_current_plugin }

  def chunk(delta:, finish_reason: nil)
    choice = { delta: delta }
    choice[:finish_reason] = finish_reason if finish_reason
    { choices: [choice] }
  end

  it "marks completed tool calls as non-partial when streaming switches tools" do
    processor = described_class.new(partial_tool_calls: true)

    # Start streaming first tool call
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_weather", function: { name: "lookup_weather", arguments: "" } },
          ],
        },
      ),
    )

    # Stream argument content for first tool
    partial =
      processor.process_streamed_message(
        chunk(delta: { tool_calls: [{ index: 0, function: { arguments: '{"location":"SFO"}' } }] }),
      )

    expect(partial).to be_a(DiscourseAi::Completions::ToolCall)
    expect(partial.partial?).to eq(true)
    expect(partial.parameters).to eq({ location: "SFO" })

    # Start streaming a second tool call – this should finalize the first one
    completed =
      processor.process_streamed_message(
        chunk(
          delta: {
            tool_calls: [
              {
                index: 1,
                id: "call_calendar",
                function: {
                  name: "create_calendar_event",
                  arguments: "",
                },
              },
            ],
          },
        ),
      )

    expect(completed).to be_a(DiscourseAi::Completions::ToolCall)
    expect(completed.name).to eq("lookup_weather")
    expect(completed.parameters).to eq({ location: "SFO" })
    expect(completed.partial?).to eq(false), "completed tool should not remain marked as partial"

    # Stream argument content for the second tool
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [{ index: 1, function: { arguments: '{"title":"Pack","time":"18:00"}' } }],
        },
      ),
    )

    # Finish streaming – the final tool should also be marked as not partial
    final_tool = processor.process_streamed_message(chunk(delta: {}, finish_reason: "stop"))

    expect(final_tool).to be_a(DiscourseAi::Completions::ToolCall)
    expect(final_tool.name).to eq("create_calendar_event")
    expect(final_tool.parameters).to eq({ title: "Pack", time: "18:00" })
    expect(final_tool.partial?).to eq(false)
  end

  it "parses streamed arguments with padding" do
    processor = described_class.new

    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_group", function: { name: "resolve", arguments: " {\"kind" } },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, function: { arguments: "\":\"group\",\"query\":\"friend\"} " } },
          ],
        },
      ),
    )

    tool = processor.process_streamed_message(chunk(delta: {}, finish_reason: "tool_calls"))

    expect(tool.parameters).to eq({ kind: "group", query: "friend" })
  end

  it "repairs a missing opening delimiter" do
    processor = described_class.new

    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            {
              index: 0,
              id: "call_group",
              function: {
                name: "resolve",
                arguments: "kind\": \"group\", \"query\": \"friend\"} ",
              },
            },
          ],
        },
      ),
    )

    tool = processor.process_streamed_message(chunk(delta: {}, finish_reason: "tool_calls"))

    expect(tool.parameters).to eq({ kind: "group", query: "friend" })
  end

  it "raises on invalid tool arguments" do
    processor = described_class.new

    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_group", function: { name: "resolve", arguments: "not-json" } },
          ],
        },
      ),
    )

    expect {
      processor.process_streamed_message(chunk(delta: {}, finish_reason: "tool_calls"))
    }.to raise_error(JSON::ParserError)
  end

  it "separates uncached, cache-read, and cache-write input tokens" do
    processor = described_class.new

    processor.process_message(
      choices: [],
      usage: {
        prompt_tokens: 2_006,
        completion_tokens: 300,
        prompt_tokens_details: {
          cached_tokens: 1_920,
          cache_write_tokens: 64,
        },
      },
    )

    expect(processor.prompt_tokens).to eq(22)
    expect(processor.completion_tokens).to eq(300)
    expect(processor.cache_read_tokens).to eq(1_920)
    expect(processor.cache_write_tokens).to eq(64)
  end
end
