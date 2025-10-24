# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Scripted::HttpClient do
  fab!(:user)
  fab!(:model, :llm_model)

  before { enable_current_plugin }

  def weather_tool_definition
    DiscourseAi::Completions::ToolDefinition.from_hash(
      name: "lookup_weather",
      description: "Fetch weather details",
      parameters: [
        { name: "location", type: "string", description: "City", required: true },
        { name: "units", type: "string", description: "Units c/f", required: true },
      ],
    )
  end

  def calendar_tool_definition
    DiscourseAi::Completions::ToolDefinition.from_hash(
      name: "create_calendar_event",
      description: "Create a calendar event",
      parameters: [
        { name: "title", type: "string", description: "Event title", required: true },
        { name: "time", type: "string", description: "Time slot", required: true },
      ],
    )
  end

  it "returns canned responses via the real endpoint stack" do
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["scripted reply"],
      llm: model.id,
      transport: :scripted_http,
    ) do |_helper, _llm, prompts, _prompt_options|
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a helpful bot",
          messages: [{ type: :user, content: "Hello?" }],
        )

      result = DiscourseAi::Completions::Llm.proxy(model.id).generate(prompt, user: user)

      expect(result).to eq("scripted reply")
      expect(prompts.last.messages.last[:content]).to eq("Hello?")
    end
  end

  it "streams responses using randomized chunking" do
    chunks = []

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Streaming reply"],
      llm: model.id,
      transport: :scripted_http,
    ) do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Stream it",
          messages: [{ type: :user, content: "Say something" }],
        )

      result =
        DiscourseAi::Completions::Llm
          .proxy(model.id)
          .generate(prompt, user: user) { |partial| chunks << partial if partial.is_a?(String) }

      expect(result).to eq("Streaming reply")
    end

    expect(chunks.join).to eq("Streaming reply")
    expect(chunks.length).to be > 1
  end

  it "streams tool call responses with partial updates" do
    partials = []

    DiscourseAi::Completions::Llm.with_prepared_responses(
      [{ tool_call: { name: "lookup_weather", arguments: { location: "SFO", units: "f" } } }],
      llm: model.id,
      transport: :scripted_http,
    ) do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Call the tool",
          messages: [{ type: :user, content: "Plan my day" }],
          tools: [weather_tool_definition],
        )

      DiscourseAi::Completions::Llm
        .proxy(model.id)
        .generate(prompt, user: user, partial_tool_calls: true) do |partial|
          partials << partial.dup if partial.is_a?(DiscourseAi::Completions::ToolCall)
        end
    end

    final = partials.find { |p| !p.partial }

    expect(final.parameters).to eq({ location: "SFO", units: "f" })
    expect(partials).not_to be_empty
    expect(partials.any?(&:partial?)).to be(true)
    expect(partials.last).not_to be_partial
  end

  it "streams multiple tool calls with partial updates" do
    partials = []

    DiscourseAi::Completions::Llm.with_prepared_responses(
      [
        {
          tool_calls: [
            { name: "lookup_weather", arguments: { location: "SFO", units: "f" } },
            { name: "create_calendar_event", arguments: { title: "Go outside", time: "09:00" } },
          ],
        },
      ],
      llm: model.id,
      transport: :scripted_http,
    ) do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Plan my day",
          messages: [{ type: :user, content: "Check weather and set reminder." }],
          tools: [weather_tool_definition, calendar_tool_definition],
        )

      final =
        DiscourseAi::Completions::Llm
          .proxy(model.id)
          .generate(prompt, user: user, partial_tool_calls: true) do |partial|
            partials << partial.dup if partial.is_a?(DiscourseAi::Completions::ToolCall)
          end
    end

    final = partials.select { |p| !p.partial }

    expect(final.length).to eq(2)
    expect(final.map(&:name)).to eq(%w[lookup_weather create_calendar_event])
    expect(final.first.parameters).to eq({ location: "SFO", units: "f" })
    expect(final.last.parameters).to eq({ title: "Go outside", time: "09:00" })
    expect(partials).not_to be_empty
    expect(partials.any?(&:partial?)).to be(true)
    expect(partials.map(&:name).uniq).to include("lookup_weather", "create_calendar_event")
    expect(partials.last).not_to be_partial
  end
end
