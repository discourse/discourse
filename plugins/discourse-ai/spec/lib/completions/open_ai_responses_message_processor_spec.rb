# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OpenAiResponsesMessageProcessor do
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
end
