# frozen_string_literal: true

require_relative "../../evals/lib/judge"
require_relative "../../evals/lib/eval"

RSpec.describe DiscourseAi::Evals::Judge do
  subject(:judge) { described_class.new(eval_case: eval_case, judge_llm: judge_llm) }

  let(:eval_case) do
    instance_double(
      DiscourseAi::Evals::Eval,
      id: "example",
      args: {
        input: "Source text",
      },
      judge: {
        criteria: "Score the candidate output based on how well it explains the input.",
        pass_rating: 7,
      },
    )
  end

  let(:llm_proxy) { instance_spy(DiscourseAi::Completions::Llm) }
  let(:judge_llm) { instance_double(LlmModel, to_llm: llm_proxy) }
  let(:judge_response) { { "rating" => 8, "explanation" => "Looks good" }.to_json }

  before { allow(llm_proxy).to receive(:generate).and_return(judge_response) }

  it "returns a passing result when the rating meets the threshold" do
    expect(judge.evaluate("great output")[:result]).to eq(:pass)
  end

  it "returns a failing result when the rating is below the threshold" do
    allow(llm_proxy).to receive(:generate).and_return(
      { "rating" => 5, "explanation" => "bad" }.to_json,
    )

    result = judge.evaluate("bad output")

    expect(result[:result]).to eq(:fail)
    expect(result[:message]).to include("below threshold")
  end

  it "substitutes placeholders from hash results" do
    judge.evaluate({ result: "hash-output" })

    expect(llm_proxy).to have_received(:generate).with(
      satisfy { |prompt| prompt.messages.any? { |msg| msg[:content].include?("hash-output") } },
      user: Discourse.system_user,
      temperature: 0,
      response_format: DiscourseAi::Evals::Judge::RESPONSE_FORMAT,
    )
  end
end
