# frozen_string_literal: true

require_relative "../../evals/lib/recorder"
require_relative "../../evals/lib/structured_logger"
require_relative "../../evals/lib/eval"

RSpec.describe DiscourseAi::Evals::Recorder do
  subject(:recorder) do
    described_class.new(eval_case, logger, "/tmp/example.json", structured_logger, output: output)
  end

  let(:eval_case) do
    instance_double("DiscourseAi::Evals::Eval", id: "example-eval", to_json: { foo: "bar" })
  end
  let(:logger) { instance_double(Logger, info: nil, error: nil) }
  let(:structured_logger) do
    instance_double(
      DiscourseAi::Evals::StructuredLogger,
      start_root: nil,
      root_started?: root_started,
      add_child_step: child_step,
      append_entry: nil,
      finish_root: nil,
      to_trace_event_json: "{}",
      path: "/tmp/example.json",
    )
  end
  let(:root_started) { true }
  let(:child_step) { {} }
  let(:output) { StringIO.new }

  before do
    allow(recorder).to receive(:attach_thread_loggers) # rubocop:disable RSpec/SubjectStub
    allow(recorder).to receive(:detach_thread_loggers) # rubocop:disable RSpec/SubjectStub
  end

  describe "#running" do
    it "starts a root structured log step for the eval" do
      recorder.running

      expect(structured_logger).to have_received(:start_root).with(
        name: "Evaluating example-eval",
        args: {
          foo: "bar",
        },
      )
      expect(logger).to have_received(:info).with("Starting evaluation 'example-eval'")
    end
  end

  describe "#record_llm_skip" do
    context "when structured logging has not started" do
      let(:root_started) { false }

      it "raises an informative error" do
        expect { recorder.record_llm_skip("gpt-4", "vision-only feature") }.to raise_error(
          ArgumentError,
          "You didn't instantiated this object with #with_cassette",
        )
      end
    end

    it "logs the skip reason when the structured log is active" do
      recorder.record_llm_skip("gpt-4", "vision-only feature")

      expect(logger).to have_received(:info).with(
        "Skipping LLM: gpt-4 - Reason: vision-only feature",
      )
    end
  end

  describe "#record_llm_results" do
    let(:results) do
      [
        { result: :pass },
        {
          result: :fail,
          message: "Mismatch",
          expected_output: "ideal",
          actual_output: "oops",
          context: "details",
        },
      ]
    end
    let(:start_time) { Time.utc(2024, 1, 1, 12, 0, 0) }
    let(:now) { Time.utc(2024, 1, 1, 12, 1, 0) }

    before { allow(Time).to receive(:now).and_return(now) }

    context "when structured logging has not started" do
      let(:root_started) { false }

      it "raises an informative error" do
        expect { recorder.record_llm_results("gpt-4", results, start_time) }.to raise_error(
          ArgumentError,
          "You didn't instantiated this object with #with_cassette",
        )
      end
    end

    it "records structured log entries and prints human friendly output" do
      recorder.record_llm_results("gpt-4", results, start_time)

      expect(structured_logger).to have_received(:add_child_step).with(
        name: "Evaluating with LLM: gpt-4",
      )
      expect(structured_logger).to have_received(:append_entry).with(
        step: child_step,
        name: :good,
        started_at: start_time,
        ended_at: now.utc,
      )
      expect(structured_logger).to have_received(:append_entry).with(
        step: child_step,
        name: :bad,
        started_at: start_time,
        ended_at: now.utc,
      )

      expect(logger).to have_received(:info).with("Evaluating with LLM: gpt-4")
      expect(logger).to have_received(:error).with("Evaluation failed with LLM: gpt-4")

      expect(output.string).to include("gpt-4: ")
      expect(output.string).to include("Passed 🟢")
      expect(output.string).to include("Failed 🔴")
      expect(output.string).to include("---- Expected ----\nideal")
      expect(output.string).to include("---- Actual ----\noops")
    end
  end
end
