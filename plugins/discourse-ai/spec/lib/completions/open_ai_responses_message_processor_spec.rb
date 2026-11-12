# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OpenAiResponsesMessageProcessor do
  describe "completion metadata" do
    it "captures non-streaming incomplete response metadata" do
      processor = described_class.new
      response = {
        status: "incomplete",
        incomplete_details: {
          reason: "max_output_tokens",
        },
        usage: {
          input_tokens: 10,
          output_tokens: 5,
          output_tokens_details: {
            reasoning_tokens: 5,
          },
        },
      }
      processor.process_message(response)
      expect(processor).to have_attributes(
        stop_reason: "max_output_tokens",
        output_limit_reached: true,
        reasoning_tokens: 5,
      )
    end

    it "captures streamed incomplete response metadata" do
      processor = described_class.new
      response = {
        status: "incomplete",
        incomplete_details: {
          reason: "max_output_tokens",
        },
        usage: {
          input_tokens: 10,
          output_tokens: 5,
          output_tokens_details: {
            reasoning_tokens: 5,
          },
        },
      }
      processor.process_streamed_message(type: "response.incomplete", response: response)
      expect(processor).to have_attributes(
        stop_reason: "max_output_tokens",
        output_limit_reached: true,
        reasoning_tokens: 5,
      )
    end

    it "captures incomplete metadata without replaying terminal native output items" do
      processor = described_class.new(output_thinking: true)
      processor.process_streamed_message(
        type: "response.incomplete",
        response: {
          status: "incomplete",
          incomplete_details: {
            reason: "max_output_tokens",
          },
          output: [
            { type: "web_search_call", id: "ws_1", action: { type: "search", query: "Query" } },
          ],
          usage: {
            input_tokens: 10,
            output_tokens: 5,
            output_tokens_details: {
              reasoning_tokens: 5,
            },
          },
        },
      )
      expect(processor.finish).to eq([])
      expect(processor).to have_attributes(
        stop_reason: "max_output_tokens",
        output_limit_reached: true,
        reasoning_tokens: 5,
      )
    end

    it "updates usage on completion and distinguishes zero from missing reasoning usage" do
      processor = described_class.new
      processor.process_streamed_message(
        type: "response.created",
        response: {
          usage: {
            input_tokens: 10,
            output_tokens: 0,
          },
        },
      )
      expect(processor.reasoning_tokens).to be_nil
      processor.process_streamed_message(
        type: "response.completed",
        response: {
          status: "completed",
          usage: {
            input_tokens: 12,
            output_tokens: 8,
            output_tokens_details: {
              reasoning_tokens: 0,
            },
          },
        },
      )
      expect(processor).to have_attributes(
        stop_reason: "completed",
        output_limit_reached: false,
        completion_tokens: 8,
        reasoning_tokens: 0,
      )
      processor.process_message(
        status: "incomplete",
        incomplete_details: {
          reason: "content_filter",
        },
      )
      expect(processor).to have_attributes(
        stop_reason: "content_filter",
        output_limit_reached: false,
      )
    end
  end

  describe "native web tool activity" do
    it "emits a thinking item for streamed web search calls" do
      processor = described_class.new(output_thinking: true)

      streamed_web_search_item = {
        id: "ws_1",
        type: "web_search_call",
        status: "completed",
        action: {
          type: "search",
          queries: ["Hacker News homepage"],
          query: "Hacker News homepage",
        },
      }
      completed_web_search_item = {
        **streamed_web_search_item,
        action: {
          **streamed_web_search_item[:action],
          sources: [
            { type: "url_citation", url: "https://news.ycombinator.com", title: "Hacker News" },
          ],
        },
      }
      result =
        processor.process_streamed_message(
          type: "response.output_item.done",
          item: streamed_web_search_item,
        )

      message_item = {
        id: "msg_1",
        type: "message",
        role: "assistant",
        content: [
          {
            type: "output_text",
            text: "HN summary",
            annotations: [
              { type: "url_citation", url: "https://news.ycombinator.com", title: "Hacker News" },
            ],
          },
        ],
      }
      processor.process_streamed_message(type: "response.output_item.done", item: message_item)
      processor.process_streamed_message(
        type: "response.completed",
        response: {
          output: [completed_web_search_item, message_item],
        },
      )

      provider_result = processor.finish.last

      expect(result).to be_a(DiscourseAi::Completions::Thinking)
      expect(result.message).to eq("Web search: Hacker News homepage")
      expect(result.provider_info).to eq({})
      expect(result).not_to be_partial
      expect(provider_result.provider_info.dig(:open_ai_responses, :output_items)).to eq(
        [completed_web_search_item, message_item],
      )
    end

    it "emits a thinking item for non-streamed web search calls" do
      processor = described_class.new(output_thinking: true)

      output_items = [
        {
          id: "ws_1",
          type: "web_search_call",
          status: "completed",
          action: {
            type: "search",
            query: "Hacker News homepage",
          },
        },
        { id: "msg_1", type: "message", content: [{ type: "output_text", text: "HN summary" }] },
      ]
      result = processor.process_message(output: output_items)

      expect(result.first).to be_a(DiscourseAi::Completions::Thinking)
      expect(result.first.message).to eq("Web search: Hacker News homepage")
      expect(result.first.provider_info.dig(:open_ai_responses, :output_items)).to eq(output_items)
      expect(result.last).to eq("HN summary")
    end
  end

  describe "usage" do
    it "separates uncached, cache-read, and cache-write input tokens" do
      processor = described_class.new

      processor.process_message(
        output: [],
        usage: {
          input_tokens: 2_006,
          output_tokens: 300,
          input_tokens_details: {
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
end
