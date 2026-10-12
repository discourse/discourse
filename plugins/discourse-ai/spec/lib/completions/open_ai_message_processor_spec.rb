# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::OpenAiMessageProcessor do
  before { enable_current_plugin }

  def chunk(delta:, finish_reason: nil)
    choice = { delta: delta }
    choice[:finish_reason] = finish_reason if finish_reason
    { choices: [choice] }
  end

  it "retains every tool call in a single streamed chunk" do
    [false, true].each do |partial_tool_calls|
      processor = described_class.new(partial_tool_calls: partial_tool_calls)
      calls = [
        { index: 0, id: "call_sam", function: { name: "search", arguments: '{"query":"sam"}' } },
        { index: 1, id: "call_dan", function: { name: "search", arguments: '{"query":"dan"}' } },
        { index: 2, id: "call_alex", function: { name: "search", arguments: '{"query":"alex"}' } },
      ]

      emitted =
        Array(
          processor.process_streamed_message(
            chunk(delta: { tool_calls: calls }, finish_reason: "tool_calls"),
          ),
        )
      emitted.concat(processor.finish)
      completed = emitted.reject(&:partial?)

      expect(completed.map(&:id)).to eq(%w[call_sam call_dan call_alex])
      expect(completed.map(&:parameters)).to eq(
        [{ query: "sam" }, { query: "dan" }, { query: "alex" }],
      )
      expect(processor.finish).to eq([])
    end
  end

  it "assembles interleaved argument fragments by tool index" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_sam", function: { name: "search", arguments: '{"query":"' } },
            { index: 1, id: "call_dan", function: { name: "search", arguments: '{"query":"' } },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 1, function: { arguments: 'dan"}' } },
            { index: 0, function: { arguments: 'sam"}' } },
          ],
        },
      ),
    )

    completed = processor.finish

    expect(completed.map(&:id)).to eq(%w[call_sam call_dan])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(completed).to all(have_attributes(partial: false))
  end

  it "tracks partial progress independently for each tool call" do
    processor = described_class.new(partial_tool_calls: true)
    progress =
      Array(
        processor.process_streamed_message(
          chunk(
            delta: {
              tool_calls: [
                {
                  index: 0,
                  id: "call_sam",
                  function: {
                    name: "search",
                    arguments: '{"query":"sam',
                  },
                },
                {
                  index: 1,
                  id: "call_dan",
                  function: {
                    name: "search",
                    arguments: '{"query":"dan',
                  },
                },
              ],
            },
          ),
        ),
      )

    expect(progress.map(&:id)).to eq(%w[call_sam call_dan])
    expect(progress.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(progress).to all(have_attributes(partial: true))

    progress =
      Array(
        processor.process_streamed_message(
          chunk(
            delta: {
              tool_calls: [
                { index: 1, function: { arguments: 'iel"}' } },
                { index: 0, function: { arguments: 'uel"}' } },
              ],
            },
          ),
        ),
      )

    expect(progress.map(&:parameters)).to eq([{ query: "daniel" }, { query: "samuel" }])
    completed =
      Array(processor.process_streamed_message(chunk(delta: {}, finish_reason: "tool_calls")))
    expect(completed.map(&:parameters)).to eq([{ query: "samuel" }, { query: "daniel" }])
    expect(completed).to all(have_attributes(partial: false))
    expect(processor.finish).to eq([])
  end

  it "assembles calls by ID when indexes are omitted" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { id: "call_sam", function: { name: "search", arguments: '{"query":"' } },
            { id: "call_dan", function: { name: "search", arguments: '{"query":"' } },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { id: "call_dan", function: { arguments: 'dan"}' } },
            { id: "call_sam", function: { arguments: 'sam"}' } },
          ],
        },
      ),
    )

    completed = processor.finish

    expect(completed.map(&:id)).to eq(%w[call_sam call_dan])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
  end

  it "retains successive calls when a server reuses a tool index" do
    processor = described_class.new
    emitted = []
    %w[sam dan].each do |query|
      emitted.concat(
        Array(
          processor.process_streamed_message(
            chunk(
              delta: {
                tool_calls: [
                  {
                    index: 0,
                    id: "call_#{query}",
                    function: {
                      name: "search",
                      arguments: { query: query }.to_json,
                    },
                  },
                ],
              },
            ),
          ),
        ),
      )
    end
    emitted.concat(processor.finish)

    expect(emitted.map(&:id)).to eq(%w[call_sam call_dan])
    expect(emitted.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(emitted).to all(have_attributes(partial: false))
  end

  it "assembles fragments when a call switches between index and ID identification" do
    [true, false].each do |indexed_header|
      processor = described_class.new
      header = { id: "call_sam", function: { name: "search", arguments: '{"query":"' } }
      header[:index] = 0 if indexed_header
      continuation = { function: { arguments: 'sam"}' } }
      continuation[indexed_header ? :id : :index] = indexed_header ? "call_sam" : 0
      processor.process_streamed_message(chunk(delta: { tool_calls: [header] }))
      processor.process_streamed_message(chunk(delta: { tool_calls: [continuation] }))

      completed = processor.finish

      expect(completed.map(&:id)).to eq(["call_sam"])
      expect(completed.map(&:parameters)).to eq([{ query: "sam" }])
      expect(processor.finish).to eq([])
    end
  end

  it "matches a continuation by ID when its index changes" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_sam", function: { name: "search", arguments: '{"query":' } },
            { index: 1, id: "call_dan", function: { name: "search", arguments: '{"query":' } },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 2, id: "call_sam", function: { arguments: '"sam"}' } },
            { index: 0, id: "call_dan", function: { arguments: '"dan"}' } },
          ],
        },
      ),
    )

    completed = processor.finish

    expect(completed.map(&:id)).to eq(%w[call_sam call_dan])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(processor.finish).to eq([])
  end

  it "registers an index introduced by an ID-bearing continuation" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [{ id: "call_sam", function: { name: "search", arguments: '{"query":"' } }],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(delta: { tool_calls: [{ index: 0, id: "call_sam", function: { arguments: "sam" } }] }),
    )
    processor.process_streamed_message(
      chunk(delta: { tool_calls: [{ index: 0, function: { arguments: '"}' } }] }),
    )

    completed = processor.finish

    expect(completed.map(&:id)).to eq(["call_sam"])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }])
    expect(processor.finish).to eq([])
  end

  it "keeps an unknown continuation ID from corrupting an indexed call" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            {
              index: 0,
              id: "call_sam",
              function: {
                name: "search",
                arguments: '{"query":"sam"}',
              },
            },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [{ index: 0, id: "call_dan", function: { arguments: '{"query":"dan"}' } }],
        },
      ),
    )

    completed = processor.finish

    expect(completed.map(&:id)).to eq(["call_sam"])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }])
  end

  it "keeps distinct indexed headers separate when their IDs match" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            {
              index: 0,
              id: "call_search",
              function: {
                name: "search",
                arguments: '{"query":"sam"}',
              },
            },
            {
              index: 1,
              id: "call_search",
              function: {
                name: "search",
                arguments: '{"query":"dan"}',
              },
            },
          ],
        },
      ),
    )

    expect(processor.finish.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
  end

  it "removes every alias when a tool index is reused" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [
            { index: 0, id: "call_sam", function: { name: "search", arguments: '{"query":' } },
          ],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(delta: { tool_calls: [{ id: "call_sam", function: { arguments: '"sam"}' } }] }),
    )
    emitted =
      Array(
        processor.process_streamed_message(
          chunk(
            delta: {
              tool_calls: [
                {
                  index: 0,
                  id: "call_dan",
                  function: {
                    name: "search",
                    arguments: '{"query":"dan"}',
                  },
                },
              ],
            },
          ),
        ),
      )
    emitted.concat(processor.finish)

    expect(emitted.map(&:id)).to eq(%w[call_sam call_dan])
    expect(emitted.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(emitted).to all(have_attributes(partial: false))
    expect(processor.finish).to eq([])
  end

  it "accepts unindexed argument fragments for the current call" do
    processor = described_class.new
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [{ id: "call_sam", function: { name: "search", arguments: '{"query":"' } }],
        },
      ),
    )
    processor.process_streamed_message(
      chunk(delta: { tool_calls: [{ function: { arguments: 'sam"}' } }] }),
    )

    expect(processor.finish.map(&:parameters)).to eq([{ query: "sam" }])
  end

  it "preserves content and finalizes all calls on an empty tool delta" do
    processor = described_class.new
    content =
      processor.process_streamed_message(
        chunk(
          delta: {
            content: "\n",
            tool_calls: [
              {
                index: 0,
                id: "call_sam",
                function: {
                  name: "search",
                  arguments: '{"query":"sam"}',
                },
              },
              {
                index: 1,
                id: "call_dan",
                function: {
                  name: "search",
                  arguments: '{"query":"dan"}',
                },
              },
            ],
          },
        ),
      )

    completed = processor.process_streamed_message(chunk(delta: { tool_calls: [] }))

    expect(content).to eq("\n")
    expect(completed.map(&:id)).to eq(%w[call_sam call_dan])
    expect(completed.map(&:parameters)).to eq([{ query: "sam" }, { query: "dan" }])
    expect(processor.finish).to eq([])
  end

  it "keeps earlier tool calls partial until the stream finishes" do
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

    progress =
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

    expect(progress).to be_nil
    expect(partial.partial?).to eq(true)

    # Stream argument content for the second tool
    processor.process_streamed_message(
      chunk(
        delta: {
          tool_calls: [{ index: 1, function: { arguments: '{"title":"Pack","time":"18:00"}' } }],
        },
      ),
    )

    completed = processor.process_streamed_message(chunk(delta: {}, finish_reason: "stop"))

    expect(completed.map(&:name)).to eq(%w[lookup_weather create_calendar_event])
    expect(completed.map(&:parameters)).to eq(
      [{ location: "SFO" }, { title: "Pack", time: "18:00" }],
    )
    expect(completed).to all(have_attributes(partial: false))
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
