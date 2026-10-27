# frozen_string_literal: true

describe DiscourseAi::Discoveries::Synthesis do
  subject(:synthesis) { described_class.new(user:, ai_agent:, llm_model:) }

  fab!(:user) { Fabricate(:user, locale: "fr") }
  fab!(:llm_model)
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      tools: [],
      response_format: [
        { "key" => "answerable", "type" => "boolean" },
        { "key" => "source_refs", "type" => "array", "array_type" => "string", "max_items" => 4 },
        { "key" => "title", "type" => "string" },
        { "key" => "answer", "type" => "string" },
        { "key" => "follow_up", "type" => "string" },
      ],
      temperature: 0.3,
      top_p: 0.8,
    )
  end

  before { enable_current_plugin }

  it "lets the model return as many sources as the request asks for" do
    agent = nil
    allow(DiscourseAi::Agents::Bot).to receive(:as) do |_user, **kwargs|
      agent = kwargs[:agent]
      raise StopIteration
    end

    expect {
      synthesis.call(
        query: "plugins",
        candidates: [{ "source_ref" => "source_1", "title" => "Plugins", "url" => "/t/plugins/1" }],
        related_count: 6,
      )
    }.to raise_error(StopIteration)

    source_refs = agent.response_format.find { |field| field["key"] == "source_refs" }
    expect(source_refs["max_items"]).to eq(6)
  end

  it "leaves out unset flags, whether the post is the first, and a same-day last update" do
    candidate = {
      "source_ref" => "source_1",
      "title" => "Plugins",
      "url" => "/t/plugins/1/3",
      "passages" => [{ "post_number" => 3, "excerpt" => "Use the skeleton." }],
      "created" => Time.utc(2026, 8, 1, 9),
      "author_is_staff" => false,
      "is_topic_op" => false,
      "topic_replies" => 0,
      "post_updated_at" => "2026-08-01T18:00:00.000000Z",
    }

    supplied_candidates =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ answerable: false, source_refs: [], title: "", answer: "" }],
      ) do |_, _, prompts|
        synthesis.call(query: "plugins", candidates: [candidate])
        JSON.parse(prompts.first.messages.last[:content]).fetch("candidates")
      end

    expect(supplied_candidates).to eq(
      [
        {
          "source_ref" => "source_1",
          "title" => "Plugins",
          "url" => "/t/1/3",
          "passages" => [{ "post_number" => 3, "excerpt" => "Use the skeleton." }],
          "created" => "2026-08-01",
          "topic_replies" => 0,
        },
      ],
    )
  end

  it "flags a solved candidate and its answer passage" do
    candidate = {
      "source_ref" => "source_1",
      "title" => "Robot stuck",
      "url" => "/t/robot-stuck/1/1",
      "solved" => true,
      "passages" => [
        { "post_number" => 1, "excerpt" => "My robot is stuck." },
        { "post_number" => 4, "excerpt" => "Restart it.", "answer" => true },
      ],
    }

    supplied_candidates =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ answerable: false, source_refs: [], title: "", answer: "" }],
      ) do |_, _, prompts|
        synthesis.call(query: "robot stuck", candidates: [candidate])
        JSON.parse(prompts.first.messages.last[:content]).fetch("candidates")
      end

    expect(supplied_candidates.first).to include(
      "solved" => true,
      "passages" => [
        { "post_number" => 1, "excerpt" => "My robot is stuck." },
        { "post_number" => 4, "excerpt" => "Restart it.", "answer" => true },
      ],
    )
  end

  it "sends an external candidate's publish date as a day and its link unchanged" do
    candidate = {
      "source_ref" => "source_1",
      "kind" => "external",
      "source_name" => "Help center",
      "title" => "Plugin quickstart",
      "url" => "https://kb.example.com/t/plugins/12",
      "excerpt" => "The full quickstart.",
      "published_at" => "2026-09-01T10:00:00Z",
    }

    supplied_candidates =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [{ answerable: false, source_refs: [], title: "", answer: "" }],
      ) do |_, _, prompts|
        synthesis.call(query: "plugins", candidates: [candidate])
        JSON.parse(prompts.first.messages.last[:content]).fetch("candidates")
      end

    expect(supplied_candidates).to eq(
      [
        {
          "source_ref" => "source_1",
          "source_name" => "Help center",
          "title" => "Plugin quickstart",
          "url" => "https://kb.example.com/t/plugins/12",
          "excerpt" => "The full quickstart.",
          "last_updated_at" => "2026-09-01",
        },
      ],
    )
  end

  it "uses one tool-free structured call to select sources and stream an answer" do
    SiteSetting.ai_ask_ai_related_count = 4
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
        "username" => "sam",
        "excerpt" => "Start with the plugin skeleton.",
        "passages" => [
          { "post_number" => 1, "excerpt" => "Start with the plugin skeleton." },
          { "post_number" => 10, "excerpt" => "Then register the plugin." },
        ],
        "created" => "2026-08-01T09:00:00.000000Z",
        "category" => "Documentation > Developer Guides",
        "likes" => 12,
        "topic_views" => 300,
        "topic_likes" => 24,
        "topic_replies" => 8,
        "tags" => "plugin, development",
        "author_is_staff" => true,
        "is_topic_op" => true,
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
          synthesis.call(
            query: "怎么删除具备管理员权限的幽灵机器人用户？",
            candidates:,
            keyword_query: "order:likes",
            original_query_locale: "zh_CN",
            related_count: 4,
          ) { |update| updates << update }

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
        expect(supplied_input.fetch("original_query_locale")).to eq("zh_CN")
        expect(supplied_input.keys).to contain_exactly(
          "original_query",
          "original_query_locale",
          "retrieval",
          "settings",
          "candidates",
        )
        expect(supplied_input.fetch("retrieval")).to eq("keyword_query" => "order:likes")
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
              "url" => "/t/123",
              "username" => "sam",
              "passages" => [
                { "post_number" => 1, "excerpt" => "Start with the plugin skeleton." },
                { "post_number" => 10, "excerpt" => "Then register the plugin." },
              ],
              "created" => "2026-08-01",
              "category" => "Documentation > Developer Guides",
              "likes" => 12,
              "topic_views" => 300,
              "topic_likes" => 24,
              "topic_replies" => 8,
              "tags" => "plugin, development",
              "author_is_staff" => true,
              "last_updated_at" => "2026-08-12",
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
    expect(feature_name).to eq("ask_ai")
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
        expect(properties.keys).to contain_exactly(
          :answerable,
          :source_refs,
          :title,
          :answer,
          :follow_up,
        )
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

  it "rejects an answer when none of its source references are supplied candidates" do
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

  it "keeps an answer whose known source references survive alongside invalid ones" do
    candidates =
      %w[source_1 source_2 source_3].map do |source_ref|
        { "source_ref" => source_ref, "title" => "Plugins", "excerpt" => "Use the skeleton." }
      end

    result =
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          {
            answerable: true,
            source_refs: %w[source_9 source_2 source_2 source_1 source_3],
            title: "Plugin guide",
            answer: "Use the plugin skeleton.",
          },
        ],
      ) { synthesis.call(query: "how do I create a plugin", candidates:, related_count: 2) }

    expect(result).to have_attributes(
      answerable: true,
      source_refs: %w[source_2 source_1],
      answer: "Use the plugin skeleton.",
    )
  end

  it "returns the suggested follow-up question alongside the answer" do
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
            title: "Plugin guide",
            answer: "Use the plugin skeleton.",
            follow_up: "How do I publish a plugin?",
          },
        ],
      ) { synthesis.call(query: "how do I create a plugin", candidates:) }

    expect(result).to have_attributes(
      answerable: true,
      answer: "Use the plugin skeleton.",
      follow_up: "How do I publish a plugin?",
    )
  end

  it "drops a suggested follow-up returned with an abstention" do
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
            title: "",
            answer: "",
            follow_up: "How do I publish a plugin?",
          },
        ],
      ) { synthesis.call(query: "how do I create a plugin", candidates:) }

    expect(result).to have_attributes(answerable: false, follow_up: "")
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

  it "streams source references only once the array is complete when the answer comes first" do
    candidates =
      %w[source_4 source_1 source_13].map do |source_ref|
        { "source_ref" => source_ref, "title" => "Python", "excerpt" => "Use the API." }
      end
    chunks = [
      "{\n  \"answer\": \"Use the REST API.\",",
      "\n  \"answerable\": true,",
      "\n  \"source_refs\": [\n    \"source_4",
      "\",\n    \"source_1",
      "3\",\n    \"source_1\"",
      "\n  ],\n  \"title\": \"Python\"\n}",
    ]
    output =
      DiscourseAi::Completions::StructuredOutput.new(
        answer: {
          type: "string",
        },
        answerable: {
          type: "boolean",
        },
        source_refs: {
          type: "array",
        },
        title: {
          type: "string",
        },
      )
    bot = instance_double(DiscourseAi::Agents::Bot)
    allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
    allow(bot).to receive(:reply) do |_, &stream|
      chunks.each do |chunk|
        output << chunk
        stream.call(output, nil, :structured_output)
      end
      output.finish
      stream.call(output, nil, :structured_output)
    end
    streamed_refs = []

    result =
      synthesis.call(query: "python", candidates:, related_count: 3) do |update|
        streamed_refs << update[:source_refs] if update[:source_refs]
      end

    expect(streamed_refs.uniq).to eq([%w[source_4 source_13 source_1]])
    expect(result.answerable).to eq(true)
    expect(result.source_refs).to eq(%w[source_4 source_13 source_1])
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
        allow(partial).to receive(:property_complete?).and_return(true)
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
        allow(partial).to receive(:property_complete?).and_return(true)
        stream.call(partial, nil, :structured_output)
      end
    end

    result = synthesis.call(query: "how do I create a plugin", candidates:)

    expect(result.answer).to eq("Start with the plugin skeleton.\n\nThen add the feature code.")
  end
end
