# frozen_string_literal: true

require_relative "../../evals/lib/workbench"
require_relative "../../evals/lib/eval"
require_relative "../../evals/lib/llm_repository"
require_relative "../../evals/lib/recorder"

RSpec.describe DiscourseAi::Evals::Workbench do
  subject(:workbench) { described_class.new(output: output) }

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
    Fabricate.build(
      :fake_model,
      display_name: "gpt-4",
      name: "gpt-4",
      vision_enabled: llm_supports_vision,
    )
  end
  let(:llm_supports_vision) { true }

  before do
    allow(DiscourseAi::Evals::Recorder).to receive(:with_cassette).and_return(recorder)
    freeze_time
  end

  describe "#run" do
    it "records results for each llm" do
      allow(workbench).to receive(:execute_eval).and_return([{ result: :pass }]) # rubocop:disable RSpec/SubjectStub

      workbench.run(eval_case: eval_case, llms: [llm])

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
        workbench.run(eval_case: eval_case, llms: [llm])

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
        allow(workbench).to receive(:execute_eval).and_raise(error) # rubocop:disable RSpec/SubjectStub

        workbench.run(eval_case: eval_case, llms: [llm])

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
        allow(workbench).to receive(:execute_eval).and_raise(StandardError.new("kaboom")) # rubocop:disable RSpec/SubjectStub

        workbench.run(eval_case: eval_case, llms: [llm])

        expect(recorder).to have_received(:record_llm_results).with(
          "gpt-4",
          [{ message: "kaboom", result: :fail }],
          Time.now.utc,
        )
      end
    end
  end

  describe "feature execution flows" do
    fab!(:category)
    let(:llm) { Fabricate(:fake_model, display_name: "Fake Eval Model", vision_enabled: false) }
    let(:workbench) { described_class.new(output: output) }

    before do
      enable_current_plugin
      ensure_system_persona(DiscourseAi::Personas::Summarizer)
      ensure_system_persona(DiscourseAi::Personas::ShortSummarizer)
      ensure_system_persona(DiscourseAi::Personas::SpamDetector)
      AiPersona.persona_cache.flush!
    end

    it "generates topic summaries using the summarization eval feature" do
      eval_case =
        OpenStruct.new(
          id: "topic-summary",
          feature: "summarization:topic_summaries",
          args: {
            input: "First post\nSecond post",
          },
          expected_output: "Concise summary",
          expected_output_regex: nil,
          expected_tool_call: nil,
          judge: nil,
        )

      results =
        DiscourseAi::Completions::Llm.with_prepared_responses(["Concise summary"]) do
          workbench.execute_eval(eval_case, llm)
        end

      expect(results.first[:result]).to eq(:pass)
    end

    it "flags spam posts via the spam inspection eval feature" do
      eval_case =
        OpenStruct.new(
          id: "spam-eval",
          feature: "spam:inspect_posts",
          args: {
            input: "Buy now click now http://spam.test",
            topic_title: "Limited offer",
          },
          expected_output: "true",
          expected_output_regex: nil,
          expected_tool_call: nil,
          judge: nil,
        )

      results =
        DiscourseAi::Completions::Llm.with_prepared_responses([true, "obvious spam"]) do
          workbench.execute_eval(eval_case, llm)
        end

      expect(results.first[:result]).to eq(:pass)
    end
  end

  def ensure_system_persona(persona_class)
    persona_id = DiscourseAi::Personas::Persona.system_personas[persona_class]
    base = persona_class.new

    AiPersona
      .find_or_initialize_by(id: persona_id)
      .tap do |persona|
        persona.system = true
        persona.enabled = true
        persona.priority ||= false
        persona.name ||= persona_class.name
        persona.description ||= persona_class.description
        persona.system_prompt = base.system_prompt
        persona.allowed_group_ids = [Group::AUTO_GROUPS[:everyone]]
        persona.response_format = base.response_format
        persona.examples = base.examples
        persona.temperature = base.respond_to?(:temperature) ? base.temperature : nil
        persona.top_p = base.respond_to?(:top_p) ? base.top_p : nil
        persona.tool_details = true
        persona.tools ||= []
        persona.save!(validate: false)
      end
  end
end
