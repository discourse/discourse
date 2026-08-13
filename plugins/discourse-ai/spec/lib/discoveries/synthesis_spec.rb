# frozen_string_literal: true

describe DiscourseAi::Discoveries::Synthesis do
  subject(:synthesis) { described_class.new(user:, llm_model:) }

  fab!(:user)
  fab!(:llm_model)

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
      ) do |_, _, prompts|
        response =
          synthesis.call(query: "how do I create a plugin", candidates:) do |update|
            updates << update
          end

        prompt = prompts.first
        expect(prompt.tools).to be_empty
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
end
