# frozen_string_literal: true

describe DiscourseAi::Discoveries::Synthesis do
  subject(:synthesis) { described_class.new(user:, ai_agent:, llm_model:) }

  fab!(:user) { Fabricate(:user, locale: "fr") }
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
    SiteSetting.ai_discover_related_count = 4
    feature_name = nil
    allow(DiscourseAi::Agents::BotContext).to receive(:new).and_wrap_original do |original, **args|
      feature_name = args[:feature_name]
      original.call(**args)
    end
    candidates = [
      {
        "source_ref" => "source_1",
        "topic_id" => 123,
        "post_id" => 456,
        "title" => "Create a Discourse plugin",
        "url" => "/t/create-a-plugin/123",
        "excerpt" => "Start with the plugin skeleton.",
        "category" => "Developer Guides",
        "post_updated_at" => "2026-08-12T10:30:00.000000Z",
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
          synthesis.call(query: "怎么删除具备管理员权限的幽灵机器人用户？", candidates:, related_count: 4) do |update|
            updates << update
          end

        prompt = prompts.first
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
                      source_refs: include(type: "array", maxItems: 4),
                      title: include(type: "string"),
                      answer: include(type: "string"),
                    ),
                ),
            ),
        )
        supplied_input = JSON.parse(prompt.messages.last[:content])
        expect(supplied_input.fetch("original_query")).to eq("怎么删除具备管理员权限的幽灵机器人用户？")
        expect(supplied_input.fetch("user_locale")).to eq("fr")
        expect(supplied_input.fetch("settings")).to eq(
          "summary_detail" => "balanced",
          "related_count" => 4,
        )
        supplied_candidates = supplied_input.fetch("candidates")
        expect(supplied_candidates).to eq(
          [
            {
              "source_ref" => "source_1",
              "title" => "Create a Discourse plugin",
              "excerpt" => "Start with the plugin skeleton.",
              "category" => "Developer Guides",
              "last_updated_at" => "2026-08-12T10:30:00.000000Z",
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
    expect(feature_name).to eq("discover")
  end

  it "keeps the fixed response contract for quiet summaries" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            answerable: true,
            source_refs: %w[source_1],
            title: "",
            answer: "Use the plugin skeleton.",
          },
        ],
      ) do |_, _, _, prompt_options|
        response =
          synthesis.call(query: "how do I create a plugin", candidates:, summary_detail: :quiet)

        properties = prompt_options.first.dig(:response_format, :json_schema, :schema, :properties)
        expect(properties.keys).to contain_exactly(:answerable, :source_refs, :title, :answer)
        response
      end

    expect(result).to have_attributes(
      answerable: true,
      source_refs: %w[source_1],
      title: "",
      answer: "Use the plugin skeleton.",
    )
  end

  it "does not repeat structured sources in the answer text" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
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
            title: "Create a plugin",
            answer:
              "Start with the plugin skeleton [[source_1]].\n\n**Sources:**\n- [Create a Discourse plugin](https://example.com/source_1)",
          },
        ],
      ) do
        synthesis.call(query: "how do I create a plugin", candidates:) do |update|
          updates << update
        end
      end

    expect(result.answer).to eq("Start with the plugin skeleton.")
    expect(updates.last[:answer]).to eq("Start with the plugin skeleton.")
  end

  it "returns an empty result without calling the model when there are no candidates" do
    allow(DiscourseAi::Agents::Bot).to receive(:as)

    result = synthesis.call(query: "miyazaki", candidates: [])

    expect(DiscourseAi::Agents::Bot).not_to have_received(:as)
    expect(result).to have_attributes(answerable: false, source_refs: [], title: "", answer: "")
  end

  it "rejects an answerable response with a placeholder answer" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ answerable: true, source_refs: %w[source_1], title: "Plugin guide", answer: "true" }],
      ) { synthesis.call(query: "how do I create a plugin", candidates:) }

    expect(result).to have_attributes(answerable: false, source_refs: [], title: "", answer: "")
  end

  it "rejects source references outside the supplied candidates" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            answerable: true,
            source_refs: %w[source_2],
            title: "Plugin guide",
            answer: "Use the plugin skeleton.",
          },
        ],
      ) { synthesis.call(query: "how do I create a plugin", candidates:) }

    expect(result).to have_attributes(answerable: false, source_refs: [], title: "", answer: "")
  end

  it "clears fields returned with an abstention" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            answerable: false,
            source_refs: [],
            title: "Unwanted title",
            answer: "Adjacent advice",
          },
        ],
      ) { synthesis.call(query: "how do I create a plugin", candidates:) }

    expect(result).to have_attributes(answerable: false, source_refs: [], title: "", answer: "")
  end

  it "keeps every streamed title fragment" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]
    partials = [
      { answerable: true, source_refs: %w[source_1], title: "Create a ", answer: "" },
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

  it "keeps paragraph breaks from streamed structured answers" do
    candidates = [
      {
        "source_ref" => "source_1",
        "title" => "Create a Discourse plugin",
        "excerpt" => "Start with the plugin skeleton.",
      },
    ]
    partials = [
      {
        answerable: true,
        source_refs: %w[source_1],
        title: "Plugin guide",
        answer: "Start with the plugin skeleton.",
      },
      { answerable: true, source_refs: %w[source_1], title: "", answer: "\n\n" },
      {
        answerable: true,
        source_refs: %w[source_1],
        title: "",
        answer: "Then add the feature code.",
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

    expect(result.answer).to eq("Start with the plugin skeleton.\n\nThen add the feature code.")
  end
end
