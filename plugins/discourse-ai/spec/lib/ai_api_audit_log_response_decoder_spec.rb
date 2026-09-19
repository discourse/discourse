# frozen_string_literal: true

RSpec.describe DiscourseAi::AiApiAuditLogResponseDecoder do
  subject(:decode) { described_class.decode(raw_response, truncated:) }

  let(:truncated) { false }

  def sse(*events)
    events.map { |event| "data: #{event.is_a?(String) ? event : event.to_json}\n\n" }.join
  end

  describe ".decode" do
    context "with OpenAI-compatible events" do
      let(:raw_response) do
        sse(
          { choices: [{ delta: { reasoning: "No" } }] },
          { choices: [{ delta: { reasoning: " funny" } }] },
          { choices: [{ delta: { reasoning: " stories" } }] },
          "[DONE]",
        )
      end

      it "assembles the retained VLLM reasoning fragments in order" do
        expect(decode).to eq("thinking" => "No funny stories")
      end
    end

    it "supports CRLF records, comments, event fields, multiline data, and a done sentinel" do
      raw_response = <<~SSE.gsub("\n", "\r\n")
        : keepalive

        event: message
        data: {"choices":[
        data: {"delta":{"content":"Hello"}}]}

        event: complete
        data: [DONE]

      SSE

      result = described_class.decode(raw_response)

      expect(result).to eq("response" => "Hello")
    end

    it "distinguishes structured model output from a decoded transcript" do
      raw_response = sse({ choices: [{ delta: { content: '{"thinking":"about this"}' } }] })

      result = described_class.decode(raw_response)

      expect(result).to eq("response" => '{"thinking":"about this"}')
    end

    it "keeps reasoning and answer channels separate" do
      cases = {
        sse({ choices: [{ delta: { content: "answer" } }] }) => {
          "response" => "answer",
        },
        sse({ choices: [{ delta: { reasoning_content: "reasoning" } }] }) => {
          "thinking" => "reasoning",
        },
        sse(
          { choices: [{ delta: { reasoning: "reason" } }] },
          { choices: [{ delta: { content: "answer" } }] },
        ) => {
          "thinking" => "reason",
          "response" => "answer",
        },
      }

      cases.each do |payload, expected|
        result = described_class.decode(payload)
        expect(result).to eq(expected)
      end
    end

    it "extracts verified readable fields from supported SSE provider events" do
      cases = {
        "OpenAI Responses" => [
          { type: "response.reasoning_summary_text.delta", delta: "reason" },
          { type: "response.output_text.delta", delta: "answer" },
          { "thinking" => "reason", "response" => "answer" },
        ],
        "Anthropic" => [
          { type: "content_block_delta", delta: { type: "thinking_delta", thinking: "reason" } },
          { type: "content_block_delta", delta: { type: "text_delta", text: "answer" } },
          { "thinking" => "reason", "response" => "answer" },
        ],
        "Gemini content" => [
          {
            candidates: [
              { content: { parts: [{ thought: true, text: "reason" }, { text: "answer" }] } },
            ],
          },
          { usageMetadata: { candidatesTokenCount: 2 } },
          { "thinking" => "reason", "response" => "answer" },
        ],
        "Gemini Interactions" => [
          {
            event_type: "step.delta",
            delta: {
              type: "thought_summary",
              content: {
                text: "reason",
              },
            },
          },
          { event_type: "step.delta", delta: { type: "text", text: "answer" } },
          { "thinking" => "reason", "response" => "answer" },
        ],
      }

      cases.each do |provider, (first_event, second_event, expected)|
        result = described_class.decode(sse(first_event, second_event, "[DONE]"))
        expect(result).to eq(expected), provider
      end
    end

    it "reconstructs fragmented tool calls from supported SSE provider events" do
      cases = {
        "OpenAI-compatible" => [
          {
            choices: [
              {
                index: 0,
                delta: {
                  tool_calls: [
                    { index: 0, id: "call-1", function: { name: "search", arguments: '{"q":"' } },
                  ],
                },
              },
            ],
          },
          {
            choices: [
              {
                index: 0,
                delta: {
                  tool_calls: [{ index: 0, function: { arguments: 'docs"}' } }],
                },
                finish_reason: "tool_calls",
              },
            ],
          },
          { "id" => "call-1", "name" => "search", "arguments" => { "q" => "docs" } },
        ],
        "Anthropic" => [
          {
            type: "content_block_start",
            index: 0,
            content_block: {
              type: "tool_use",
              id: "tool-1",
              name: "search",
              input: {
              },
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: '{"q":"docs"}',
            },
          },
          { type: "content_block_stop", index: 0 },
          { "id" => "tool-1", "name" => "search", "arguments" => { "q" => "docs" } },
        ],
        "Gemini Interactions" => [
          {
            event_type: "step.start",
            index: 0,
            step: {
              type: "function_call",
              id: "call-1",
              name: "search",
              arguments: '{"q":"',
            },
          },
          {
            event_type: "step.delta",
            index: 0,
            delta: {
              type: "arguments",
              partial_arguments: 'docs"}',
            },
          },
          { event_type: "step.stop", index: 0 },
          { "id" => "call-1", "name" => "search", "arguments" => { "q" => "docs" } },
        ],
      }

      cases.each do |provider, entries|
        expected = entries.pop
        result = described_class.decode(sse(*entries))
        expect(result).to eq("tool_calls" => [expected]), provider
      end
    end

    it "deduplicates complete OpenAI Responses tool-call snapshots" do
      item = {
        id: "item-1",
        type: "function_call",
        call_id: "call-1",
        name: "search",
        arguments: '{"q":"docs"}',
      }
      raw_response =
        sse(
          { type: "response.output_item.added", item: item.merge(arguments: "") },
          { type: "response.function_call_arguments.delta", item_id: "item-1", delta: '{"q":' },
          { type: "response.function_call_arguments.delta", item_id: "item-1", delta: '"docs"}' },
          {
            type: "response.function_call_arguments.done",
            item_id: "item-1",
            arguments: item[:arguments],
          },
          { type: "response.output_item.done", item: item },
          { type: "response.completed", response: { output: [item] } },
        )

      result = described_class.decode(raw_response)

      expect(result).to eq(
        "tool_calls" => [
          { "id" => "call-1", "name" => "search", "arguments" => { "q" => "docs" } },
        ],
      )
    end

    it "extracts complete Gemini, Cohere, and Ollama tool calls" do
      payloads = {
        sse(
          {
            candidates: [
              { content: { parts: [{ functionCall: { name: "search", args: { q: "docs" } } }] } },
            ],
          },
        ) => {
          "name" => "search",
          "arguments" => {
            "q" => "docs",
          },
        },
        [
          { event_type: "stream-start" },
          {
            event_type: "tool-calls-generation",
            tool_calls: [{ name: "search", parameters: { q: "docs" } }],
          },
          { event_type: "stream-end" },
        ].map(&:to_json).join("\n") => {
          "name" => "search",
          "arguments" => {
            "q" => "docs",
          },
        },
        [
          {
            message: {
              tool_calls: [{ function: { name: "search", arguments: { q: "docs" } } }],
            },
            done: false,
          },
          { message: { content: "" }, done: true },
        ].map(&:to_json).join("\n") => {
          "name" => "search",
          "arguments" => {
            "q" => "docs",
          },
        },
      }

      payloads.each do |payload, expected|
        result = described_class.decode(payload)
        expect(result).to eq("tool_calls" => [expected])
      end
    end

    it "includes thinking, server tool calls, results, and the final response" do
      raw_response =
        sse(
          {
            event_type: "step.delta",
            delta: {
              type: "thought_summary",
              content: {
                text: "Check it",
              },
            },
          },
          {
            event_type: "step.start",
            index: 0,
            step: {
              type: "code_execution_call",
              id: "code-1",
            },
          },
          {
            event_type: "step.delta",
            index: 0,
            delta: {
              type: "code_execution_call",
              arguments: {
                language: "python",
                code: "print(42)",
              },
            },
          },
          { event_type: "step.stop", index: 0 },
          {
            event_type: "step.start",
            index: 1,
            step: {
              type: "code_execution_result",
              call_id: "code-1",
            },
          },
          {
            event_type: "step.delta",
            index: 1,
            delta: {
              type: "code_execution_result",
              result: "42\n",
              is_error: false,
            },
          },
          { event_type: "step.stop", index: 1 },
          { event_type: "step.delta", delta: { type: "text", text: "42" } },
        )

      result = described_class.decode(raw_response)

      expect(result).to eq(
        "thinking" => "Check it",
        "tool_calls" => [
          {
            "id" => "code-1",
            "name" => "code_execution",
            "arguments" => {
              "language" => "python",
              "code" => "print(42)",
            },
          },
        ],
        "tool_results" => [
          {
            "call_id" => "code-1",
            "type" => "code_execution_result",
            "result" => "42\n",
            "is_error" => false,
          },
        ],
        "response" => "42",
      )
    end

    it "falls back atomically for incomplete or conflicting tool calls" do
      incomplete =
        sse(
          {
            type: "content_block_start",
            index: 0,
            content_block: {
              type: "tool_use",
              id: "tool-1",
              name: "search",
              input: {
              },
            },
          },
          {
            type: "content_block_delta",
            index: 0,
            delta: {
              type: "input_json_delta",
              partial_json: '{"q":',
            },
          },
        )
      conflicting =
        sse(
          {
            type: "response.output_item.added",
            item: {
              id: "item-1",
              type: "function_call",
              call_id: "call-1",
              name: "search",
              arguments: "",
            },
          },
          { type: "response.function_call_arguments.delta", item_id: "item-1", delta: "{}" },
          {
            type: "response.output_item.done",
            item: {
              id: "item-1",
              type: "function_call",
              call_id: "call-1",
              name: "search",
              arguments: '{"q":"different"}',
            },
          },
        )

      [incomplete, conflicting].each do |payload|
        result = described_class.decode(payload)
        expect(result).to be_nil
      end
    end

    it "extracts Anthropic content block initial text" do
      raw_response =
        sse(
          { type: "content_block_start", content_block: { type: "thinking", thinking: "why" } },
          { type: "content_block_start", content_block: { type: "text", text: "yes" } },
        )

      result = described_class.decode(raw_response)

      expect(result).to eq("thinking" => "why", "response" => "yes")
    end

    it "decodes newline-delimited Ollama content" do
      raw_response = [
        { message: { role: "assistant", content: "Hello " }, done: false },
        { message: { role: "assistant", content: "world" }, done: false },
        { message: { role: "assistant", content: "" }, done: true },
      ].map(&:to_json).join("\n")

      result = described_class.decode(raw_response)

      expect(result).to eq("response" => "Hello world")
    end

    it "decodes Ollama thinking separately from content" do
      raw_response = [
        { message: { thinking: "Check", content: "" }, done: false },
        { message: { thinking: " first", content: "Answer" }, done: false },
        { message: { thinking: "", content: "" }, done: true },
      ].map(&:to_json).join("\n")

      result = described_class.decode(raw_response)

      expect(result).to eq("thinking" => "Check first", "response" => "Answer")
    end

    it "separates Cohere tool rationale from generated response text" do
      raw_response = [
        { event_type: "stream-start", text: "metadata" },
        { event_type: "tool-calls-generation", text: "I will search" },
        { event_type: "text-generation", text: "Hello" },
        { event_type: "stream-end", response: { text: "duplicate" } },
      ].map(&:to_json).join("\n")

      result = described_class.decode(raw_response)

      expect(result).to eq("thinking" => "I will search", "response" => "Hello")
    end

    it "preserves JSON escapes, Unicode, and fragment whitespace" do
      raw_response =
        sse(
          { choices: [{ delta: { content: "A quoted \"word\"" } }] },
          { choices: [{ delta: { content: " and café ☕" } }] },
        )

      result = described_class.decode(raw_response)

      expect(result).to eq("response" => "A quoted \"word\" and café ☕")
    end

    it "falls back for non-streaming JSON, plain text, nil, and blank input" do
      payloads = ['{"choices":[{"message":{"content":"hello"}}]}', "server error", nil, " \n"]

      payloads.each do |payload|
        result = described_class.decode(payload)
        expect(result).to be_nil
      end
    end

    it "falls back when a stream contains no known readable text" do
      payloads = [
        sse({ unknown: { text: "not supported" } }, "[DONE]"),
        sse({ choices: [{ delta: { tool_calls: [{ function: { arguments: "secret" } }] } }] }),
        sse({ type: "response.completed", response: { usage: { output_tokens: 10 } } }),
      ]

      payloads.each do |payload|
        result = described_class.decode(payload)
        expect(result).to be_nil
      end
    end

    it "atomically falls back for malformed JSON in the middle or at the end" do
      valid_event = { choices: [{ delta: { content: "partial" } }] }.to_json
      payloads = [
        "data: #{valid_event}\n\ndata: {broken}\n\ndata: #{valid_event}\n\n",
        "data: #{valid_event}\n\ndata: {\"choices\":[",
        "#{valid_event}\n{broken}\n#{valid_event}\n",
      ]

      payloads.each do |payload|
        result = described_class.decode(payload)
        expect(result).to be_nil
      end
    end

    it "falls back for a retry buffer with an error followed by a valid stream" do
      raw_response = "upstream error\n" + sse({ choices: [{ delta: { content: "answer" } }] })

      result = described_class.decode(raw_response)

      expect(result).to be_nil
    end

    it "returns nil for invalidly encoded binary input" do
      raw_response = "\x00\xFF\x01".dup.force_encoding(Encoding::UTF_8)

      result = nil
      expect { result = described_class.decode(raw_response) }.not_to raise_error
      expect(result).to be_nil
    end

    it "returns nil when the caller marks the payload as truncated" do
      raw_response = sse({ choices: [{ delta: { content: "partial" } }] })
      result = described_class.decode(raw_response, truncated: true)

      expect(result).to be_nil
    end

    it "accepts exactly the input-size limit and rejects larger payloads" do
      prefix = 'data: {"choices":[{"delta":{"content":"'
      suffix = "\"}}]}\n\n"
      fragment = "a" * (described_class::MAX_INPUT_BYTES - prefix.bytesize - suffix.bytesize)
      at_limit = prefix + fragment + suffix
      over_limit = at_limit.sub(fragment, "#{fragment}a")

      expect(at_limit.bytesize).to eq(described_class::MAX_INPUT_BYTES)
      expect(described_class.decode(at_limit)).to eq("response" => fragment)
      expect(described_class.decode(over_limit)).to be_nil
    end

    it "accepts the event-count limit and atomically falls back above it" do
      readable_event = { choices: [{ delta: { content: "answer" } }] }
      formats = {
        "SSE" => ->(events) { sse(*events, "[DONE]") },
        "NDJSON" => ->(events) { events.map(&:to_json).join("\n") },
      }

      formats.each do |transport, encode|
        at_limit_events = [readable_event] + Array.new(described_class::MAX_EVENTS - 1) { {} }
        over_limit_events = [readable_event] + Array.new(described_class::MAX_EVENTS) { {} }
        at_limit = encode.call(at_limit_events)
        over_limit = encode.call(over_limit_events)

        expect(described_class.decode(at_limit)).to eq("response" => "answer"), transport
        expect(described_class.decode(over_limit)).to be_nil, transport
      end
    end

    it "does not mutate the input" do
      expected_raw_response = sse({ choices: [{ delta: { content: "answer" } }] })
      raw_response = expected_raw_response.freeze

      result = nil
      expect { result = described_class.decode(raw_response) }.not_to raise_error
      expect(result).to eq("response" => "answer")
      expect(raw_response).to eq(expected_raw_response)
    end
  end
end
