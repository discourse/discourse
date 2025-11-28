# frozen_string_literal: true

require_relative "../../evals/lib/workbench"
require_relative "../../evals/lib/judge"

RSpec.describe DiscourseAi::Evals::Workbench do
  let(:output) { StringIO.new }
  let(:eval_case) do
    OpenStruct.new(
      id: "topic-summary",
      judge: {
        criteria: "accuracy",
        pass_rating: 8,
      },
      feature: "dummy",
      args: {
      },
    )
  end
  let(:llm_one) { Fabricate(:fake_model, display_name: "LLM One") }
  let(:llm_two) { Fabricate(:fake_model, display_name: "LLM Two") }
  let(:persona_variants) { [{ key: "default", prompt: nil }, { key: "custom", prompt: "prompt" }] }

  describe "#compare with judge in persona mode" do
    let(:judge_llm) { Fabricate(:fake_model) }
    let(:workbench) { described_class.new(output: output, judge_llm: judge_llm, comparison: true) }
    let(:recorder) do
      instance_double(
        DiscourseAi::Evals::Recorder,
        record_llm_results: nil,
        record_llm_skip: nil,
        announce_comparison_judged: nil,
        announce_comparison_expected: nil,
        announce_comparison_aggregate: nil,
        finish: nil,
      )
    end

    before do
      allow(DiscourseAi::Evals::Recorder).to receive(:with_cassette).and_return(recorder)
      allow(workbench).to receive(:execute_eval).and_return(
        { raw: "default out", raw_entries: ["default out"], classified: [{ result: :pass }] },
        { raw: "custom out", raw_entries: ["custom out"], classified: [{ result: :pass }] },
      )
      allow_any_instance_of(DiscourseAi::Evals::Judge).to receive(:compare).and_return(
        winner: "custom",
        winner_label: "Candidate 2",
        ratings: [
          { candidate: "default", rating: 6, explanation: "ok" },
          { candidate: "custom", rating: 9, explanation: "great" },
        ],
        winner_explanation: "better",
      )
    end

    it "announces judged comparison with resolved winner labels" do
      workbench.compare(
        eval_cases: [eval_case],
        llms: [llm_one],
        persona_variants: persona_variants,
      )

      expect(recorder).to have_received(:announce_comparison_judged).with(
        eval_case_id: "topic-summary",
        mode_label: "personas",
        persona_key: "default",
        result:
          a_hash_including(
            winner: "custom",
            winner_label: "Candidate 2",
            winner_explanation: "better",
            ratings: [
              { candidate: "default", rating: 6, explanation: "ok" },
              { candidate: "custom", rating: 9, explanation: "great" },
            ],
          ),
      )
    end
  end

  describe "#compare expected-output aggregate" do
    let(:workbench) { described_class.new(output: output, judge_llm: nil, comparison: :llms) }
    let(:recorder) do
      instance_double(
        DiscourseAi::Evals::Recorder,
        record_llm_results: nil,
        record_llm_skip: nil,
        announce_comparison_judged: nil,
        announce_comparison_expected: nil,
        announce_comparison_aggregate: nil,
        finish: nil,
      )
    end

    let(:eval_case) { OpenStruct.new(id: "spam_eval", judge: nil, args: nil, feature: "dummy") }

    before do
      allow(DiscourseAi::Evals::Recorder).to receive(:with_cassette).and_return(recorder)
      allow(DiscourseAi::Evals::Judge).to receive(:new).and_raise("judge should not be called")
      allow(workbench).to receive(:execute_eval).and_return(
        { raw: "out one", raw_entries: ["out one"], classified: [{ result: :pass }] },
        {
          raw: "out two",
          raw_entries: ["out two"],
          classified: [
            { result: :pass },
            { result: :fail, expected_output: "true", actual_output: "false" },
          ],
        },
      )
    end

    it "announces expected comparison and aggregates totals across evals" do
      workbench.compare(
        eval_cases: [eval_case],
        llms: [llm_one, llm_two],
        persona_variants: [{ key: "default", prompt: nil }],
      )

      expect(recorder).to have_received(:announce_comparison_expected).with(
        eval_case_id: "spam_eval",
        mode_label: "LLMs",
        persona_key: "default",
        winner: "LLM One",
        status_line: "LLM One 🟢 -- LLM Two 🔴",
        failures: [{ label: "LLM Two", expected: "true", actual: "false" }],
      )
      expect(recorder).to have_received(:announce_comparison_aggregate).with(
        mode_label: "LLMs",
        persona_key: "default",
        aggregate_scores: {
          "LLM One" => {
            evals: 1,
            passes: 1,
          },
          "LLM Two" => {
            evals: 1,
            passes: 0,
          },
        },
      )
    end
  end
end
