# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::AppearanceAuthoring::StyleAuthor do
  fab!(:admin)
  fab!(:llm_model)

  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:palettes) { { light: ColorScheme.base_colors, dark: ColorScheme::BUILT_IN_SCHEMES[:Dark] } }
  let(:valid_answer) do
    {
      "variables" => [{ "name" => "--d-border-radius", "value" => "12px" }],
      "rules" => [
        {
          "area" => "topic_list_item",
          "state" => "hover",
          "media" => "",
          "page" => "",
          "declarations" => [
            { "property" => "box-shadow", "value" => "0 2px 8px rgba(var(--primary-rgb), 0.08)" },
          ],
        },
      ],
      "unsupported" => ["Add a link to the shop in the header"],
    }
  end
  let(:invalid_answer) do
    {
      "variables" => [],
      "rules" => [
        {
          "area" => "header",
          "state" => "",
          "media" => "",
          "page" => "",
          "declarations" => [{ "property" => "position", "value" => "fixed" }],
        },
      ],
      "unsupported" => [],
    }
  end

  before { enable_current_plugin }

  def author(request = "Rounder corners and a soft shadow on topic rows")
    described_class.new(llm:, user: admin, feature_name: "admin_assistant").call(request, palettes:)
  end

  it "returns typed styles that pass the policy, with what they change" do
    result = nil
    DiscourseAi::Completions::Llm.with_prepared_responses([valid_answer]) do |_, _, prompts|
      result = author
      system_prompt = prompts.first.messages.first[:content]
      expect(system_prompt).to include("- topic_list_item: Topic list rows [hover, odd, even]")
      expect(system_prompt).to include("--d-border-radius: length, 0px to 32px")
      expect(system_prompt).not_to include("--d-skeleton")
    end

    expect(result.styles).to eq(
      "variables" => {
        "--d-border-radius" => "12px",
      },
      "rules" => [
        {
          "area" => "topic_list_item",
          "state" => "hover",
          "declarations" => {
            "box-shadow" => "0 2px 8px rgba(var(--primary-rgb), 0.08)",
          },
        },
      ],
    )
    expect(result.changes.map(&:label)).to include("--d-border-radius")
    expect(result.unsupported).to eq(["Add a link to the shop in the header"])
  end

  it "sends the policy's errors back for the model to fix" do
    result = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(
      [invalid_answer, valid_answer],
    ) do |_, _, prompts|
      result = author
      repair =
        prompts.last.messages.find do |message|
          message[:content].start_with?("Those styles were rejected")
        end
      expect(repair[:content]).to include("rules[0].position: property is not allowed")
    end

    expect(result.styles["variables"]).to eq("--d-border-radius" => "12px")
  end

  it "gives up with the last errors when the model can't get it right" do
    result = DiscourseAi::Completions::Llm.with_prepared_responses([invalid_answer] * 3) { author }

    expect(result).to be_a(described_class::Failure)
    expect(result.errors).to include("rules[0].position: property is not allowed")
  end

  it "fails when the model doesn't answer with JSON" do
    result = DiscourseAi::Completions::Llm.with_prepared_responses(["not json"]) { author }

    expect(result).to be_a(described_class::Failure)
  end
end
