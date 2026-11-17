# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::Fake do
  fab!(:llm_model, :fake_model)

  let(:response_format) do
    {
      type: "json_schema",
      json_schema: {
        name: "reply",
        schema: {
          type: "object",
          properties: {
            verdict: {
              type: "string",
            },
            confident: {
              type: "boolean",
            },
            attempts: {
              type: "integer",
            },
            reasons: {
              type: "array",
              items: {
                type: "string",
              },
            },
          },
        },
      },
    }
  end

  before { enable_current_plugin }

  it "answers a structured request with a payload shaped like the schema" do
    result =
      llm_model.to_llm.generate(
        "hello",
        user: Discourse.system_user,
        feature_name: "test",
        response_format: response_format,
      )

    expect(result).to be_a(DiscourseAi::Completions::StructuredOutput)
    expect(JSON.parse(result.to_s)).to eq(
      "verdict" => "fake verdict",
      "confident" => true,
      "attempts" => 42,
      "reasons" => ["fake reasons"],
    )
  end

  it "streams the structured payload" do
    partials = []

    llm_model
      .to_llm
      .generate(
        "hello",
        user: Discourse.system_user,
        feature_name: "test",
        response_format: response_format,
      ) { |partial| partials << partial }

    expect(partials.last).to be_a(DiscourseAi::Completions::StructuredOutput)
    expect(partials.last.read_buffered_property(:verdict)).to eq("fake verdict")
  end

  it "keeps returning explicitly set content", :aggregate_failures do
    described_class.with_fake_content({ verdict: "reject" }.to_json) do
      result =
        llm_model.to_llm.generate(
          "hello",
          user: Discourse.system_user,
          feature_name: "test",
          response_format: response_format,
        )

      expect(result.to_s).to eq({ verdict: "reject" }.to_json)
    end

    described_class.with_fake_content("a plain summary") do
      result =
        llm_model.to_llm.generate(
          "hello",
          user: Discourse.system_user,
          feature_name: "test",
          response_format: response_format,
        )

      expect(result).to eq("a plain summary")
    end
  end

  it "answers with the stock content when no schema is requested", :aggregate_failures do
    expect(
      llm_model.to_llm.generate("hello", user: Discourse.system_user, feature_name: "test"),
    ).to include("Discourse Markdown Styles Showcase")
    expect(
      llm_model.to_llm.generate(
        "hello",
        user: Discourse.system_user,
        feature_name: "test",
        response_format: {
          type: "json_object",
        },
      ),
    ).to include("Discourse Markdown Styles Showcase")
  end
end
