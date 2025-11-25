# frozen_string_literal: true

require_relative "../../evals/lib/comparison_runner"
require_relative "../../evals/lib/judge"
require_relative "../../evals/lib/workbench"

RSpec.describe DiscourseAi::Evals::ComparisonRunner do
  subject(:runner) { described_class.new(mode: mode, judge_llm: judge_llm, output: output) }

  let(:mode) { :personas }
  let(:judge_llm) { Fabricate(:fake_model) }
  let(:output) { StringIO.new }
  let(:eval_case) do
    OpenStruct.new(
      id: "topic-summary",
      args: {
        source: "input",
      },
      judge: {
        criteria: "Score accuracy",
        pass_rating: 8,
      },
    )
  end

  before { freeze_time }

  describe "#run in persona mode" do
    let(:mode) { :personas }
    let(:llm) { Fabricate(:fake_model) }
    let(:persona_variants) do
      [{ key: "default", prompt: nil }, { key: "topic_summary_eval", prompt: "custom prompt" }]
    end
    let(:workbench_default) { instance_double(DiscourseAi::Evals::Workbench) }
    let(:workbench_custom) { instance_double(DiscourseAi::Evals::Workbench) }
    let(:judge_double) do
      instance_double(
        DiscourseAi::Evals::Judge,
        compare: {
          winner: "topic_summary_eval",
          winner_label: "topic_summary_eval",
          winner_explanation: "custom captured more detail",
          ratings: [
            { candidate: "default", rating: 6, explanation: "missed details" },
            { candidate: "topic_summary_eval", rating: 9, explanation: "accurate" },
          ],
          raw: '{"winner":"topic_summary_eval"}',
        },
      )
    end

    before do
      allow(DiscourseAi::Evals::Workbench).to receive(:new).and_return(
        workbench_default,
        workbench_custom,
      )

      allow(workbench_default).to receive(:run).and_yield(
        eval_case: eval_case,
        llm: llm,
        llm_name: "Default LLM",
        persona_label: "default",
        raw_entries: ["Default output"],
        classified_entries: [{ result: :pass }],
      )
      allow(workbench_custom).to receive(:run).and_yield(
        eval_case: eval_case,
        llm: llm,
        llm_name: "Default LLM",
        persona_label: "topic_summary_eval",
        raw_entries: ["Custom output"],
        classified_entries: [{ result: :pass }],
      )

      allow(DiscourseAi::Evals::Judge).to receive(:new).and_return(judge_double)
    end

    it "collects persona outputs and sends them to the judge" do
      runner.run(eval_cases: [eval_case], persona_variants: persona_variants, llms: [llm])

      expect(DiscourseAi::Evals::Judge).to have_received(:new).with(
        eval_case: eval_case,
        judge_llm: judge_llm,
      )
      expect(judge_double).to have_received(:compare).with(
        [
          { label: "default", output: "Default output" },
          { label: "topic_summary_eval", output: "Custom output" },
        ],
      )

      expect(output.string).to include("Winner: topic_summary_eval")
      expect(output.string).to include("default: 6/10")
      expect(output.string).to include("topic_summary_eval: 9/10")
    end
  end

  describe "#run in llm mode" do
    let(:mode) { :llms }
    let(:llm_one) { Fabricate(:fake_model, display_name: "LLM One") }
    let(:llm_two) { Fabricate(:fake_model, display_name: "LLM Two") }
    let(:persona_variants) { [{ key: "default", prompt: nil }] }
    let(:workbench) { instance_double(DiscourseAi::Evals::Workbench) }
    let(:judge_double) do
      instance_double(
        DiscourseAi::Evals::Judge,
        compare: {
          winner: "LLM Two",
          winner_label: "LLM Two",
          winner_explanation: "Fewer hallucinations",
          ratings: [
            { candidate: "LLM One", rating: 5, explanation: "missed context" },
            { candidate: "LLM Two", rating: 8, explanation: "accurate" },
          ],
          raw: '{"winner":"LLM Two"}',
        },
      )
    end

    before do
      allow(DiscourseAi::Evals::Workbench).to receive(:new).and_return(workbench)
      call_sequence = [
        {
          eval_case: eval_case,
          llm: llm_one,
          llm_name: "LLM One",
          persona_label: "default",
          raw_entries: ["Output One"],
          classified_entries: [{ result: :pass }],
        },
        {
          eval_case: eval_case,
          llm: llm_two,
          llm_name: "LLM Two",
          persona_label: "default",
          raw_entries: ["Output Two"],
          classified_entries: [{ result: :pass }],
        },
      ]
      allow(workbench).to receive(:run) do |**kwargs, &block|
        expect(kwargs[:llms]).to match_array([llm_one, llm_two])
        expect(kwargs[:eval_case]).to eq(eval_case)
        call_sequence.each { |payload| block.call(payload) }
      end
      allow(DiscourseAi::Evals::Judge).to receive(:new).and_return(judge_double)
    end

    it "compares outputs from multiple llms for the same persona" do
      runner.run(
        eval_cases: [eval_case],
        persona_variants: persona_variants,
        llms: [llm_one, llm_two],
      )

      expect(judge_double).to have_received(:compare).with(
        [{ label: "LLM One", output: "Output One" }, { label: "LLM Two", output: "Output Two" }],
      )

      expect(output.string).to include("Winner: LLM Two")
      expect(output.string).to include("persona: default")
    end
  end
end
