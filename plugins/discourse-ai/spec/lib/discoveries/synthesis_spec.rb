# frozen_string_literal: true

describe DiscourseAi::Discoveries::Synthesis do
  subject(:synthesis) { described_class.new(user:, ai_agent:, llm_model:) }

  fab!(:user)
  fab!(:llm_model)
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      system_prompt: "Use the configured Discover agent prompt.",
      tools: [["Search", {}, true]],
      temperature: 0.3,
      top_p: 0.8,
    )
  end

  before { enable_current_plugin }

  it "uses one tool-free structured call to select sources and stream an answer" do
    candidates = [
      {
        "source_ref" => "source_1",
        "topic_id" => 123,
        "post_id" => 456,
        "title" => "Create a Discourse plugin",
        "url" => "/t/create-a-plugin/123",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]
    updates = []

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            answerable: true,
            source_refs: %w[source_1],
            title: "Create a Discourse plugin",
            answer: "Use the plugin skeleton.",
          },
        ],
      ) do |_, _, prompts, prompt_options|
        response =
          synthesis.call(query: "how do I create a plugin", candidates:) do |update|
            updates << update
          end

        prompt = prompts.first
        expect(prompt.system_message_text).to eq(ai_agent.system_prompt)
        expect(prompt.tools).to be_empty
        expect(prompt_options.first).to include(temperature: 0.3, top_p: 0.8)
        expect(prompt_options.first[:response_format]).to include(
          type: "json_schema",
          json_schema:
            include(
              schema:
                include(
                  properties:
                    include(
                      answerable: include(type: "boolean"),
                      source_refs: include(type: "array", maxItems: 6),
                      title: include(type: "string"),
                      answer: include(type: "string"),
                    ),
                ),
            ),
        )
        supplied_candidates = JSON.parse(prompt.messages.last[:content]).fetch("candidates")
        expect(supplied_candidates).to eq(
          [
            {
              "source_ref" => "source_1",
              "title" => "Create a Discourse plugin",
              "excerpt" => "Start with the plugin skeleton.",
            },
          ],
        )

        response
      end

    expect(result).to have_attributes(
      answerable: true,
      source_refs: %w[source_1],
      title: "Create a Discourse plugin",
      answer: "Use the plugin skeleton.",
    )
    expect(updates.last).to include(
      answerable: true,
      source_refs: %w[source_1],
      title: "Create a Discourse plugin",
      answer: "Use the plugin skeleton.",
    )
  end

  it "returns an empty result without calling the model when there are no candidates" do
    allow(DiscourseAi::Agents::Bot).to receive(:as)

    result = synthesis.call(query: "miyazaki", candidates: [])

    expect(DiscourseAi::Agents::Bot).not_to have_received(:as)
    expect(result).to have_attributes(answerable: false, source_refs: [], title: "", answer: "")
  end

  it "keeps every streamed title fragment" do
    candidates =
      [
        {
          "source_ref" => "source_1",
          "title" => "Create a Discourse plugin",
          "excerpt" => "Start with the plugin skeleton.",
        },
      ]
    partials =
      [
        {
          answerable: true,
          source_refs: %w[source_1],
          title: "Create a ",
          answer: "",
        },
        {
          answerable: true,
          source_refs: %w[source_1],
          title: "Discourse plugin",
          answer: "Use the plugin skeleton.",
        },
      ]
    bot = instance_double(DiscourseAi::Agents::Bot)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |_, &stream|
      partials.each do |values|
        partial = double
        allow(partial).to receive(:read_buffered_property) { |key| values[key] }
        stream.call(partial, nil, :structured_output)
      end
    end

    result = synthesis.call(query: "how do I create a plugin", candidates:)

    expect(result.title).to eq("Create a Discourse plugin")
  end
end
