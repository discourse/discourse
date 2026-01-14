# frozen_string_literal: true

require_relative "../../../evals/lib/runners/inference"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::Inference do
  fab!(:llm, :fake_model)

  let(:structured_output) do
    instance_double(
      DiscourseAi::Completions::StructuredOutput,
      read_buffered_property: %w[concept_a concept_b],
    )
  end
  before do
    stub_runner_bot(persona: DiscourseAi::Personas::ConceptFinder.new) do |blk|
      blk.call(structured_output, nil, :structured_output)
    end
  end

  describe "#run" do
    it "returns newline separated concepts for generate_concepts" do
      eval_case =
        OpenStruct.new(
          args: {
            input: "This topic covers deployment pipelines and observability dashboards.",
          },
        )

      runner = described_class.new("generate_concepts")
      result = runner.run(eval_case, llm)

      expect(result[:raw]).to eq("concept_a\nconcept_b")
    end

    it "uses provided concept candidates for match_concepts" do
      eval_case =
        OpenStruct.new(args: { input: "Moderation queue updates", concepts: %w[queue ai] })
      runner = described_class.new("match_concepts")
      expect(runner.run(eval_case, llm)[:raw]).to eq("concept_a\nconcept_b")
    end

    it "requires concepts for deduplicate_concepts" do
      runner = described_class.new("deduplicate_concepts")
      expect do runner.run(OpenStruct.new(args: {}), llm) end.to raise_error(
        ArgumentError,
        /requires :concepts/,
      )
    end
  end
end
