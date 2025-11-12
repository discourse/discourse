# frozen_string_literal: true

require_relative "../../evals/lib/playground"
require_relative "../../evals/lib/eval"
require_relative "../../evals/lib/llm"
require_relative "../../evals/lib/recorder"

RSpec.describe DiscourseAi::Evals::Playground do
  subject(:playground) { described_class.new(output: output) }

  let(:output) { StringIO.new }
  let(:recorder) do
    instance_double(
      DiscourseAi::Evals::Recorder,
      record_llm_skip: nil,
      record_llm_results: nil,
      finish: nil,
    )
  end
  let(:eval_case) do
    instance_double(
      DiscourseAi::Evals::Eval,
      id: "example-eval",
      vision: requires_vision,
      feature: "custom:prompt",
      args: {
      },
      expected_output: nil,
      expected_output_regex: nil,
      expected_tool_call: nil,
      judge: nil,
    )
  end
  let(:requires_vision) { false }
  let(:llm) do
    instance_double("DiscourseAi::Evals::Llm", name: "gpt-4", vision?: llm_supports_vision)
  end
  let(:llm_supports_vision) { true }

  before do
    allow(DiscourseAi::Evals::Recorder).to receive(:with_cassette).and_return(recorder)
    freeze_time
  end

  describe "#run" do
    it "records results for each llm" do
      allow(playground).to receive(:execute_eval).and_return([{ result: :pass }]) # rubocop:disable RSpec/SubjectStub

      playground.run(eval_case: eval_case, llms: [llm])

      expect(DiscourseAi::Evals::Recorder).to have_received(:with_cassette).with(
        eval_case,
        output: output,
      )
      expect(recorder).to have_received(:record_llm_results).with(
        "gpt-4",
        [{ result: :pass }],
        Time.now.utc,
      )
      expect(recorder).to have_received(:finish)
    end

    context "when the eval requires vision but the llm does not support it" do
      let(:requires_vision) { true }
      let(:llm_supports_vision) { false }

      it "skips the llm and records the reason" do
        playground.run(eval_case: eval_case, llms: [llm])

        expect(recorder).to have_received(:record_llm_skip).with(
          "gpt-4",
          "LLM does not support vision",
        )
        expect(recorder).to have_received(:finish)
      end
    end

    context "when eval execution raises an EvalError" do
      it "records the failure with the error context" do
        error = DiscourseAi::Evals::Eval::EvalError.new("boom", { foo: "bar" })
        allow(playground).to receive(:execute_eval).and_raise(error) # rubocop:disable RSpec/SubjectStub

        playground.run(eval_case: eval_case, llms: [llm])

        expect(recorder).to have_received(:record_llm_results).with(
          "gpt-4",
          [{ result: :fail, message: "boom", context: { foo: "bar" } }],
          Time.now.utc,
        )
        expect(recorder).to have_received(:finish)
      end
    end

    context "when eval execution raises an unexpected error" do
      it "records the failure with the exception message" do
        allow(playground).to receive(:execute_eval).and_raise(StandardError.new("kaboom")) # rubocop:disable RSpec/SubjectStub

        playground.run(eval_case: eval_case, llms: [llm])

        expect(recorder).to have_received(:record_llm_results).with(
          "gpt-4",
          [{ result: :fail, message: "kaboom" }],
          Time.now.utc,
        )
      end
    end
  end
end
