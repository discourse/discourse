# frozen_string_literal: true

require_relative "../../../evals/lib/runners/appearance_styles"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::AppearanceStyles do
  fab!(:llm, :fake_model)

  let(:execution_context) { DiscourseAi::Completions::ExecutionContext.new }
  let(:runner) { described_class.new("appearance_styles") }
  let(:answer) do
    {
      "variables" => [{ "name" => "--d-border-radius", "value" => "12px" }],
      "rules" => [
        {
          "area" => "share_button",
          "state" => "",
          "media" => "",
          "page" => "",
          "declarations" => [{ "property" => "display", "value" => "none" }],
        },
      ],
      "unsupported" => ["Add a shop link"],
    }
  end
  let(:invalid_answer) do
    {
      "variables" => [{ "name" => "--d-border-radius", "value" => "url(x)" }],
      "rules" => [],
      "unsupported" => [],
    }
  end

  before { enable_current_plugin }

  def run_case(**args)
    runner.run(OpenStruct.new(args:), llm, execution_context:)
  end

  it "reports checked styles as JSON for cases to match" do
    result =
      DiscourseAi::Completions::Llm.with_prepared_responses([answer]) do
        run_case(input: "Rounder corners, hide share, and a shop link")
      end

    summary = JSON.parse(result[:raw])
    expect(summary).to include(
      "result" => "styles",
      "attempts" => 1,
      "variables" => {
        "--d-border-radius" => "12px",
      },
      "unsupported" => ["Add a shop link"],
    )
    expect(summary["rules"]).to contain_exactly(
      {
        "area" => "share_button",
        "state" => nil,
        "page" => nil,
        "media" => nil,
        "properties" => {
          "display" => "none",
        },
      },
    )
    expect(result[:metadata]).to include(:seconds, :request_tokens, :response_tokens)
  end

  it "reports a failure once the answers never pass the checks" do
    result =
      DiscourseAi::Completions::Llm.with_prepared_responses([invalid_answer] * 3) do
        run_case(input: "Rounder corners")
      end

    expect(JSON.parse(result[:raw])).to include("result" => "failed", "attempts" => 3)
  end

  it "gives one attempt when measuring first answers" do
    ENV["APPEARANCE_STYLES_MAX_ATTEMPTS"] = "1"
    result =
      DiscourseAi::Completions::Llm.with_prepared_responses([invalid_answer]) do
        run_case(input: "Rounder corners")
      end

    expect(JSON.parse(result[:raw])).to include("result" => "failed", "attempts" => 1)
  ensure
    ENV.delete("APPEARANCE_STYLES_MAX_ATTEMPTS")
  end

  it "edits the current styles with palettes built from a brand color" do
    prompts = nil
    DiscourseAi::Completions::Llm.with_prepared_responses([answer]) do |_, _, captured|
      run_case(
        input: "Also hide share",
        current_styles: {
          variables: {
            "--d-border-radius" => "8px",
          },
        },
        brand_color: "#e8590c",
      )
      prompts = captured
    end

    request = prompts.first.messages.find { |message| message[:type] == :user }[:content]
    expect(request).to include('{"variables":{"--d-border-radius":"8px"}}')
    expect(prompts.first.messages.first[:content]).to include(
      "tertiary ##{ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c").light["tertiary"]}",
    )
  end
end
